defmodule TerminusDB.GraphQL do
  @moduledoc """
  GraphQL API for TerminusDB.

  Wraps the `/api/graphql/{org}/{db}` endpoint. TerminusDB auto-generates a
  GraphQL schema from the database's document schema, supporting queries
  (filter, limit, offset, orderBy, backlinks, path queries, count) and
  mutations (insert/replace/delete documents).

  This is a **thin HTTP wrapper** — users write raw GraphQL query strings.
  A programmatic query builder DSL is planned for a future release.

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")
        |> TerminusDB.Config.with_database("mydb")

      # Query
      {:ok, result} = TerminusDB.GraphQL.query(config, "{ Person { name age } }")

      # Mutation
      {:ok, result} = TerminusDB.GraphQL.mutate(config, ~s'''
        mutation {
          _insertDocuments(json: "{\\"@type\\":\\"Person\\",\\"name\\":\\"Alice\\"}")
        }
      ''')

      # Introspect schema
      {:ok, schema} = TerminusDB.GraphQL.introspect(config)

  ## Response format

  - `{:ok, %{data: data, errors: nil}}` — successful query with no errors.
  - `{:ok, %{data: data, errors: errors}}` — partial success with errors.
  - `{:ok, %{data: nil, errors: errors}}` — query failed.
  - `{:error, %Error{}}` — HTTP/transport error.

  """

  alias TerminusDB.{Client, Config, Error}
  alias TerminusDB.Client.Params

  @type graphql_opt :: {:organization, String.t()}

  @type result :: {:ok, %{data: term(), errors: [map()] | nil}} | {:error, Error.t()}

  defp graphql_path(config, opts) do
    org = opts[:organization] || config.organization

    db =
      config.database ||
        raise Error, reason: :http, message: "no database scoped in config"

    "graphql/#{org}/#{db}"
  end

  @doc """
  Executes a GraphQL query against the database.

  `query_string` is a raw GraphQL query string. `variables` is an optional
  map of variable values for parameterized queries.

  ## Options

  - `:organization` — overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"data" => %{"Person" => [%{"name" => "Alice"}]})})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, result} = TerminusDB.GraphQL.query(config, "{ Person { name } }")
      iex> result.data["Person"]
      [%{"name" => "Alice"}]

  """
  @spec query(Config.t(), String.t(), [graphql_opt()] | map()) :: result()
  def query(config, query_string, opts \\ [])

  def query(config, query_string, opts) when is_list(opts) do
    variables = Keyword.get(opts, :variables)
    do_query(config, query_string, variables, opts)
  end

  def query(config, query_string, variables) when is_map(variables) do
    do_query(config, query_string, variables, [])
  end

  defp do_query(config, query_string, variables, opts) do
    path = graphql_path(config, opts)

    body = Params.maybe_put(%{"query" => query_string}, "variables", variables)

    case Client.request(config, :post, path, json: body, area: :graphql) do
      {:ok, resp} ->
        {:ok, %{data: resp["data"], errors: resp["errors"]}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Executes a GraphQL mutation against the database.

  Same as `query/3` but conventionally used for mutations.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"data" => %{"_insertDocuments" => ["Person/Alice"]})})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, result} = TerminusDB.GraphQL.mutate(config, ~s(mutation { _insertDocuments(json: "{\\"@type\\":\\"Person\\",\\"name\\":\\"Alice\\"}") }))
      iex> result.data["_insertDocuments"]
      ["Person/Alice"]

  """
  @spec mutate(Config.t(), String.t(), [graphql_opt()] | map()) :: result()
  def mutate(config, query_string, opts \\ [])

  def mutate(config, query_string, opts) when is_list(opts) do
    variables = Keyword.get(opts, :variables)
    do_query(config, query_string, variables, opts)
  end

  def mutate(config, query_string, variables) when is_map(variables) do
    do_query(config, query_string, variables, [])
  end

  @doc """
  Introspects the GraphQL schema of the database.

  Sends a `__schema` introspection query and returns the raw schema map.

  ## Options

  - `:organization` — overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"data" => %{"__schema" => %{"types" => [%{"name" => "Person"}]})})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, schema} = TerminusDB.GraphQL.introspect(config)
      iex> schema["__schema"]["types"]
      [%{"name" => "Person"}]

  """
  @spec introspect(Config.t(), [graphql_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def introspect(config, opts \\ []) do
    introspection_query = """
    {
      __schema {
        types {
          name
          kind
          description
          fields {
            name
            type {
              name
              kind
              ofType { name kind }
            }
          }
          inputFields {
            name
            type {
              name
              kind
              ofType { name kind }
            }
          }
        }
      }
    }
    """

    case do_query(config, introspection_query, nil, opts) do
      {:ok, %{data: data}} -> {:ok, data}
      {:error, _} = error -> error
    end
  end
end
