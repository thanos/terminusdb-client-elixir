defmodule TerminusDB.Database do
  @moduledoc """
  Database management API for TerminusDB.

  A database is the top-level container holding a schema, instance data, and a full
  commit history. This module wraps the `/api/db` endpoints.

  All functions accept a `TerminusDB.Config` and return `{:ok, result}` or
  `{:error, TerminusDB.Error.t()}`. The `!/`-suffixed variants raise instead.
  The organization defaults to `config.organization` but can be overridden per call
  via the `:organization` option.

  ## Examples

      config = TerminusDB.Config.new(endpoint: "http://localhost:6363")

      {:ok, _} = TerminusDB.Database.create(config, "mydb",
        label: "My Database",
        comment: "A demo database",
        schema: true
      )

      {:ok, details} = TerminusDB.Database.info(config, "mydb")
      true = TerminusDB.Database.exists?(config, "mydb")
      {:ok, _} = TerminusDB.Database.delete(config, "mydb")

  """

  alias TerminusDB.{Client, Error}
  alias TerminusDB.Client.Params

  @type create_opt ::
          {:label, String.t()}
          | {:comment, String.t()}
          | {:schema, boolean()}
          | {:public, boolean()}
          | {:prefixes, map()}
          | {:organization, String.t()}

  @type info_opt :: {:organization, String.t()} | {:branches, boolean()} | {:verbose, boolean()}
  @type delete_opt :: {:organization, String.t()} | {:force, boolean()}

  @doc """
  Creates a new database `db_name` in the configured (or given) organization.

  ## Options

  - `:label` — human-readable name (defaults to `db_name`).
  - `:comment` — description (defaults to `""`).
  - `:schema` — whether to initialize a schema graph (default `true`).
  - `:public` — whether the database is accessible to all users.
  - `:prefixes` — custom `@base`/`@schema` IRI prefixes.
  - `:organization` — overrides `config.organization`.

  Returns `{:ok, response_body}` on success. The response is a map of the shape
  `%{"@type" => "api:DbCreateResponse", "api:status" => "api:success"}`.

  ## Examples

      iex> {:ok, _} =
      ...>   TerminusDB.Database.create(config, "mydb", label: "My DB", schema: true)

  """
  @spec create(TerminusDB.Config.t(), String.t(), [create_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def create(config, db_name, opts \\ []) do
    org = opts[:organization] || config.organization

    body =
      %{
        "label" => opts[:label] || db_name,
        "comment" => opts[:comment] || "",
        "schema" => Keyword.get(opts, :schema, true)
      }
      |> Params.maybe_put("public", opts[:public])
      |> Params.maybe_put("prefixes", opts[:prefixes])

    Client.request(config, :post, "db/#{org}/#{db_name}", json: body, area: :database)
  end

  @doc """
  Creates a database, returning the response body or raising `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> )
      iex> TerminusDB.Database.create!(config, "mydb", label: "My DB")
      %{"api:status" => "api:success"}

  """
  @spec create!(TerminusDB.Config.t(), String.t(), [create_opt()]) :: map()
  def create!(config, db_name, opts \\ []) do
    case create(config, db_name, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Deletes the database `db_name`.

  ## Options

  - `:force` — force deletion of databases in inconsistent states (default `false`).
  - `:organization` — overrides `config.organization`.

  ## Examples

      iex> {:ok, _} = TerminusDB.Database.delete(config, "mydb")
      iex> {:ok, _} = TerminusDB.Database.delete(config, "mydb", force: true)

  """
  @spec delete(TerminusDB.Config.t(), String.t(), [delete_opt()]) ::
          {:ok, map() | nil} | {:error, Error.t()}
  def delete(config, db_name, opts \\ []) do
    org = opts[:organization] || config.organization
    params = if opts[:force], do: [force: true], else: []

    Client.request(config, :delete, "db/#{org}/#{db_name}", params: params, area: :database)
  end

  @doc """
  Deletes a database, returning the response body or raising `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> )
      iex> TerminusDB.Database.delete!(config, "mydb")
      %{"api:status" => "api:success"}

  """
  @spec delete!(TerminusDB.Config.t(), String.t(), [delete_opt()]) :: map() | nil
  def delete!(config, db_name, opts \\ []) do
    case delete(config, db_name, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Returns details for the database `db_name` (a list of database descriptors).

  ## Options

  - `:branches` — include branch information (default `false`).
  - `:verbose` — return all available information (default `false`).
  - `:organization` — overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"name" => "mydb", "@type" => "UserDatabase"}])} end
      ...> )
      iex> {:ok, details} = TerminusDB.Database.info(config, "mydb")
      iex> hd(details)["name"]
      "mydb"

  """
  @spec info(TerminusDB.Config.t(), String.t(), [info_opt()]) ::
          {:ok, [map()]} | {:error, Error.t()}
  def info(config, db_name, opts \\ []) do
    org = opts[:organization] || config.organization

    params =
      Params.flag_param(:branches, opts[:branches]) ++
        Params.flag_param(:verbose, opts[:verbose])

    Client.request(config, :get, "db/#{org}/#{db_name}", params: params, area: :database)
  end

  @doc """
  Returns database details, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"name" => "mydb"}])} end
      ...> )
      iex> TerminusDB.Database.info!(config, "mydb")
      [%{"name" => "mydb"}]

  """
  @spec info!(TerminusDB.Config.t(), String.t(), [info_opt()]) :: [map()]
  def info!(config, db_name, opts \\ []) do
    case info(config, db_name, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Lists all databases available to the authenticated user.

  ## Options

  - `:branches` — include branch information (default `false`).
  - `:verbose` — return all available information (default `false`).

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"name" => "a"}, %{"name" => "b"}])} end
      ...> )
      iex> {:ok, dbs} = TerminusDB.Database.list(config)
      iex> Enum.map(dbs, & &1["name"])
      ["a", "b"]

  """
  @spec list(TerminusDB.Config.t(), [info_opt()]) :: {:ok, [map()]} | {:error, Error.t()}
  def list(config, opts \\ []) do
    params =
      Params.flag_param(:branches, opts[:branches]) ++
        Params.flag_param(:verbose, opts[:verbose])

    Client.request(config, :get, "db", params: params, area: :database)
  end

  @doc """
  Lists all databases, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"name" => "mydb"}])} end
      ...> )
      iex> TerminusDB.Database.list!(config)
      [%{"name" => "mydb"}]

  """
  @spec list!(TerminusDB.Config.t(), [info_opt()]) :: [map()]
  def list!(config, opts \\ []) do
    case list(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Returns `true` if the database `db_name` exists, `false` otherwise.

  Uses `HEAD /api/db/:org/:db`. A 404 is interpreted as "does not exist"; any other
  non-success response raises `TerminusDB.Error`.

  ## Options

  - `:organization` — overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: "")} end
      ...> )
      iex> TerminusDB.Database.exists?(config, "mydb")
      true

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 404, body: "")} end
      ...> )
      iex> TerminusDB.Database.exists?(config, "missing")
      false

  """
  @spec exists?(TerminusDB.Config.t(), String.t(), [delete_opt()]) :: boolean()
  def exists?(config, db_name, opts \\ []) do
    org = opts[:organization] || config.organization

    case Client.request_response(config, :head, "db/#{org}/#{db_name}", area: :database) do
      {:ok, _resp} -> true
      {:error, %Error{status: 404}} -> false
      {:error, error} -> raise error
    end
  end

  @doc """
  Updates metadata (label, comment, etc.) for the database `db_name`.

  Accepts the same body options as `create/3` (`:label`, `:comment`, `:schema`,
  `:public`, `:prefixes`) plus `:organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> )
      iex> {:ok, resp} = TerminusDB.Database.update(config, "mydb", label: "New Label")
      iex> resp["api:status"]
      "api:success"

  """
  @spec update(TerminusDB.Config.t(), String.t(), [create_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def update(config, db_name, opts \\ []) do
    org = opts[:organization] || config.organization

    body =
      %{
        "label" => opts[:label] || db_name,
        "comment" => opts[:comment] || "",
        "schema" => Keyword.get(opts, :schema, true)
      }
      |> Params.maybe_put("public", opts[:public])
      |> Params.maybe_put("prefixes", opts[:prefixes])

    Client.request(config, :put, "db/#{org}/#{db_name}", json: body, area: :database)
  end

  @doc """
  Updates a database, returning the response body or raising `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> )
      iex> TerminusDB.Database.update!(config, "mydb", label: "New Label")
      %{"api:status" => "api:success"}

  """
  @spec update!(TerminusDB.Config.t(), String.t(), [create_opt()]) :: map()
  def update!(config, db_name, opts \\ []) do
    case update(config, db_name, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Optimizes a resource path (branch, `_meta`, or `_commits` graph).

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Database.optimize(config, "admin/mydb/local/branch/main")
      iex> resp["api:status"]
      "api:success"

  """
  @spec optimize(TerminusDB.Config.t(), String.t()) ::
          {:ok, map()} | {:error, TerminusDB.Error.t()}
  def optimize(config, path) do
    TerminusDB.Client.request(config, :post, "optimize/#{path}", area: :database)
  end

  @doc """
  Optimizes a resource path, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> )
      iex> TerminusDB.Database.optimize!(config, "_system")
      %{"api:status" => "api:success"}

  """
  @spec optimize!(TerminusDB.Config.t(), String.t()) :: map()
  def optimize!(config, path) do
    case optimize(config, path) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  # Helpers -------------------------------------------------------------------
end
