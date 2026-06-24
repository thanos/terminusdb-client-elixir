defmodule TerminusDB.Client do
  @moduledoc """
  The HTTP wire module for `terminusdb_ex`.

  `TerminusDB.Client` is the **only** module that issues HTTP requests. Every
  higher-level API module (`TerminusDB.Database`, `TerminusDB.Document`, …)
  composes a request and delegates here. Centralizing the wire logic keeps auth,
  headers, JSON, telemetry, retries, and error mapping in one place.

  Built on [Req](https://hexdocs.pm/req). Connection context is carried by an
  immutable `TerminusDB.Config` struct.

  ## Functions

  - `request/4` — returns `{:ok, body}` or `{:error, TerminusDB.Error.t()}`.
  - `request!/4` — returns the body or raises `TerminusDB.Error`.
  - `request_response/4` — returns `{:ok, Req.Response.t()}` when the full response
    (headers, status, streamed body) is needed.

  ## Options

  In addition to the telemetry-only `:area` and `:raw` flags, request options are
  forwarded to Req: `:json` (JSON body), `:body` (raw body), `:params` (query string),
  `:into` (response streaming target), `:form`, `:form_multipart`, `:decode_body`.

  ## Examples

      # Using the Database API (preferred)
      {:ok, body} = TerminusDB.Database.create(config, "mydb", label: "My DB")

      # Using the raw client directly
      {:ok, body} =
        TerminusDB.Client.request(config, :post, "db/admin/mydb",
          json: %{label: "My DB", comment: "demo", schema: true},
          area: :database
        )

  """

  alias TerminusDB.{Config, Error, Telemetry}

  @type method :: :get | :post | :put | :patch | :delete | :head

  @doc """
  Performs an HTTP request and returns `{:ok, decoded_body}` or `{:error, Error.t()}`.

  The body is auto-decoded by Req when the response is JSON (string keys). For
  non-2xx responses, an `TerminusDB.Error` is built from the structured `api:*`
  body when present, or a generic `:http` error otherwise.

  ## Options

  See the module documentation. `:area` sets the telemetry event area
  (default `:connection`). `:raw` returns the full `Req.Response.t()` instead of
  the body.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> )
      iex> {:ok, body} = TerminusDB.Client.request(config, :get, "ok")
      iex> body["api:status"]
      "api:success"

  """
  @spec request(Config.t(), method(), String.t(), keyword()) ::
          {:ok, term()} | {:error, Error.t()}
  def request(config, method, path, opts \\ []) do
    case request_response(config, method, path, opts) do
      {:ok, resp} -> {:ok, if(opts[:raw], do: resp, else: resp.body)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Performs an HTTP request and returns the decoded body, or raises `TerminusDB.Error`.

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})}
      ...>   end
      ...> )
      iex> TerminusDB.Client.request!(config, :get, "ok")
      %{"api:status" => "api:success"}

  """
  @spec request!(Config.t(), method(), String.t(), keyword()) :: term()
  def request!(config, method, path, opts \\ []) do
    case request(config, method, path, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Performs an HTTP request and returns `{:ok, Req.Response.t()}` with the full
  response (status, headers, body). Use this when you need headers or a streamed
  body (`:into`).

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"ok" => true})} end
      ...> )
      iex> {:ok, resp} = TerminusDB.Client.request_response(config, :get, "ok")
      iex> resp.status
      200

  """
  @spec request_response(Config.t(), method(), String.t(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, Error.t()}
  def request_response(config, method, path, opts \\ []) do
    area = opts[:area] || :connection
    meta = %{method: method, path: path, area: area, config: Config.redact(config)}
    start_monotonic = Telemetry.start(area, meta, config)

    req = build_request(config, method, path, opts)

    {result, status, error} =
      case Req.request(req) do
        {:ok, resp} ->
          if resp.status in 200..299 do
            {{:ok, resp}, resp.status, nil}
          else
            error = build_status_error(resp)
            {{:error, error}, error.status, error}
          end

        {:error, exception} ->
          error = Error.transport(exception)
          {{:error, error}, nil, error}
      end

    Telemetry.stop(area, meta, start_monotonic, config, status: status, error: error)
    result
  end

  @doc """
  Builds the `organization/database` resource segment for the given config and
  options, resolving the organization from `opts[:organization]` or
  `config.organization`. Raises `TerminusDB.Error` if no database is scoped.

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      ...> |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Client.resource_path(config, [])
      "admin/mydb"
      iex> TerminusDB.Client.resource_path(config, organization: "acme")
      "acme/mydb"

  """
  @spec resource_path(Config.t(), keyword()) :: String.t()
  def resource_path(%Config{} = config, opts) do
    org = opts[:organization] || config.organization

    db =
      config.database ||
        raise Error, reason: :http, message: "no database scoped in config"

    "#{org}/#{db}"
  end

  # Request construction ------------------------------------------------------

  defp build_request(config, method, path, opts) do
    base_url = String.trim_trailing(config.endpoint, "/") <> "/api/"

    base_opts = [
      base_url: base_url,
      auth: Config.auth(config),
      receive_timeout: config.receive_timeout,
      headers: req_headers(config),
      redirect: false,
      retry: false
    ]

    base_opts =
      if config.adapter, do: Keyword.put(base_opts, :adapter, config.adapter), else: base_opts

    req = Req.new(base_opts)

    Req.merge(req, [method: method, url: path] ++ req_opts(opts))
  end

  defp req_headers(%Config{user_agent: ua, headers: headers}) do
    Map.merge(%{"user-agent" => ua}, headers)
  end

  defp req_opts(opts) do
    Keyword.take(opts, [:json, :body, :params, :into, :form, :form_multipart, :decode_body])
  end

  # Response handling ---------------------------------------------------------

  defp build_status_error(resp) do
    case resp.body do
      %{} = body ->
        Error.api(resp.status, body)

      body when is_binary(body) and body != "" ->
        case Jason.decode(body) do
          {:ok, %{} = decoded} -> Error.api(resp.status, decoded)
          _ -> Error.http(resp.status, body)
        end

      body ->
        Error.http(resp.status, body)
    end
  end
end
