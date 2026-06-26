defmodule TerminusDB.Triples do
  @moduledoc """
  Triples (turtle) API for TerminusDB.

  Wraps the `/api/triples/{path}/{graph_type}` endpoints for reading and
  writing graph contents as turtle-encoded triples.

  All functions require a `TerminusDB.Config` scoped to a database.

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")
        |> TerminusDB.Config.with_database("mydb")

      {:ok, turtle} = TerminusDB.Triples.get(config)
      {:ok, _} = TerminusDB.Triples.update(config, turtle, author: "admin", message: "replace")
      {:ok, _} = TerminusDB.Triples.insert(config, more_turtle, author: "admin", message: "add")

  """

  alias TerminusDB.{Client, Config, Error}
  alias TerminusDB.Client.Params

  @type triples_opt ::
          {:graph_type, :instance | :schema}
          | {:organization, String.t()}
          | {:repo, String.t()}
          | {:author, String.t()}
          | {:message, String.t()}

  defp triples_path(config, opts) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    branch = config.branch
    graph_type = opts[:graph_type] || :instance
    "triples/#{org}/#{db}/#{repo}/branch/#{branch}/#{graph_type}"
  end

  defp build_commit_info(opts) do
    author = opts[:author]
    message = opts[:message]

    if author || message do
      %{"author" => author || "", "message" => message || ""}
    end
  end

  @doc """
  Retrieves the contents of the specified graph as turtle-encoded triples.

  ## Options

  - `:graph_type` — `:instance` (default) or `:schema`.
  - `:organization` — overrides `config.organization`.
  - `:repo` — overrides `config.repo`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: "@prefix : <http://example.org/> .")} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, turtle} = TerminusDB.Triples.get(config)
      iex> turtle
      "@prefix : <http://example.org/> ."

  """
  @spec get(Config.t(), [triples_opt()]) :: {:ok, String.t()} | {:error, Error.t()}
  def get(config, opts \\ []) do
    path = triples_path(config, opts)
    Client.request(config, :get, path, area: :triples)
  end

  @doc """
  Retrieves triples, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: "<http://example.org/foo> <http://example.org/bar> <http://example.org/baz> .")} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Triples.get!(config)
      "<http://example.org/foo> <http://example.org/bar> <http://example.org/baz> ."

  """
  @spec get!(Config.t(), [triples_opt()]) :: String.t()
  def get!(config, opts \\ []) do
    case get(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Replaces the entire graph with the given turtle triples.

  ## Options

  - `:author` — commit author.
  - `:message` — commit message.
  - `:graph_type` — `:instance` (default) or `:schema`.
  - `:organization` — overrides `config.organization`.
  - `:repo` — overrides `config.repo`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Triples.update(config, "@prefix : <http://example.org/> .", author: "admin", message: "replace")
      iex> resp["api:status"]
      "api:success"

  """
  @spec update(Config.t(), String.t(), [triples_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def update(config, content, opts \\ []) do
    path = triples_path(config, opts)

    body =
      Params.maybe_put(%{"turtle" => content}, "commit_info", build_commit_info(opts))

    Client.request(config, :post, path, json: body, area: :triples)
  end

  @doc """
  Replaces graph with turtle triples, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Triples.update!(config, "@prefix : <http://example.org/> .")
      %{"api:status" => "api:success"}

  """
  @spec update!(Config.t(), String.t(), [triples_opt()]) :: map()
  def update!(config, content, opts \\ []) do
    case update(config, content, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Inserts turtle triples into the graph (additive).

  ## Options

  Same as `update/3`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Triples.insert(config, ":foo :bar :baz .", author: "admin", message: "add")
      iex> resp["api:status"]
      "api:success"

  """
  @spec insert(Config.t(), String.t(), [triples_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def insert(config, content, opts \\ []) do
    path = triples_path(config, opts)

    body =
      Params.maybe_put(%{"turtle" => content}, "commit_info", build_commit_info(opts))

    Client.request(config, :put, path, json: body, area: :triples)
  end

  @doc """
  Inserts turtle triples, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Triples.insert!(config, ":foo :bar :baz .")
      %{"api:status" => "api:success"}

  """
  @spec insert!(Config.t(), String.t(), [triples_opt()]) :: map()
  def insert!(config, content, opts \\ []) do
    case insert(config, content, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end
end
