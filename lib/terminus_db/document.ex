defmodule TerminusDB.Document do
  @moduledoc """
  Document CRUD and query API for TerminusDB.

  Wraps the `/api/document/{path}` endpoints. A "document" is a JSON object
  conforming to a schema class, stored as linked triples. Documents can be
  inserted, retrieved, queried by template, replaced, and deleted.

  All functions require a `TerminusDB.Config` scoped to a database (via
  `TerminusDB.Config.with_database/2`). The organization defaults to
  `config.organization` but can be overridden per call via the `:organization`
  option.

  ## Graph types

  Operations target the `:instance` graph (data) by default. Pass
  `graph_type: :schema` to operate on the schema graph (schema documents are
  documents too).

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")
        |> TerminusDB.Config.with_database("mydb")

      # Insert a schema (Class document)
      {:ok, _} =
        TerminusDB.Document.insert(config,
          %{"@type" => "Class", "@id" => "Person", "name" => "xsd:string"},
          author: "admin", message: "add schema", graph_type: :schema
        )

      # Insert a document
      {:ok, _} =
        TerminusDB.Document.insert(config,
          %{"@type" => "Person", "name" => "Alice"},
          author: "admin", message: "add Alice"
        )

      # Retrieve documents by type
      {:ok, docs} = TerminusDB.Document.get(config, type: "Person", as_list: true)

      # Query by template
      {:ok, matches} =
        TerminusDB.Document.query(config, %{"@type" => "Person", "name" => "Alice"})

      # Stream large result sets
      TerminusDB.Document.stream(config, type: "Person")
      |> Stream.each(&IO.inspect/1)
      |> Stream.run()

  """

  alias TerminusDB.{Client, Config, Error}

  @type graph_type :: :instance | :schema

  @type insert_opt ::
          {:author, String.t()}
          | {:message, String.t()}
          | {:graph_type, graph_type()}
          | {:full_replace, boolean()}
          | {:raw_json, boolean()}
          | {:organization, String.t()}

  @type get_opt ::
          {:graph_type, graph_type()}
          | {:id, String.t()}
          | {:type, String.t()}
          | {:skip, non_neg_integer()}
          | {:count, pos_integer()}
          | {:as_list, boolean()}
          | {:unfold, boolean()}
          | {:minimized, boolean()}
          | {:compress_ids, boolean()}
          | {:organization, String.t()}

  @type update_opt ::
          {:author, String.t()}
          | {:message, String.t()}
          | {:graph_type, graph_type()}
          | {:create, boolean()}
          | {:raw_json, boolean()}
          | {:organization, String.t()}

  @type delete_opt ::
          {:author, String.t()}
          | {:message, String.t()}
          | {:graph_type, graph_type()}
          | {:id, String.t()}
          | {:nuke, boolean()}
          | {:organization, String.t()}

  @type query_opt ::
          {:graph_type, graph_type()}
          | {:skip, non_neg_integer()}
          | {:count, pos_integer()}
          | {:as_list, boolean()}
          | {:organization, String.t()}

  # Path building -------------------------------------------------------------

  defp document_path(config, opts) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    "document/#{org}/#{db}"
  end

  defp graph_type_param(opts), do: [graph_type: Atom.to_string(opts[:graph_type] || :instance)]

  # Public API ----------------------------------------------------------------

  @doc """
  Inserts one or more documents into the database.

  `document` can be a single map or a list of maps. The response body from
  TerminusDB (the inserted document IDs) is returned.

  ## Options

  - `:author` — commit author (required by the API).
  - `:message` — commit message (required by the API).
  - `:graph_type` — `:instance` (default) or `:schema`.
  - `:full_replace` — if `true`, delete all existing documents before inserting.
  - `:raw_json` — if `true`, insert as untyped `sys:JSONDocument` (no schema check).
  - `:organization` — overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: [%{"@id" => "Person/Alice"}])}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, ids} = TerminusDB.Document.insert(config,
      ...>   %{"@type" => "Person", "name" => "Alice"},
      ...>   author: "admin", message: "add Alice"
      ...> )
      iex> ids
      [%{"@id" => "Person/Alice"}]

  Inserting a list of documents:

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"@id" => "Person/Alice"}, %{"@id" => "Person/Bob"}])} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, ids} = TerminusDB.Document.insert(config, [
      ...>   %{"@type" => "Person", "name" => "Alice"},
      ...>   %{"@type" => "Person", "name" => "Bob"}
      ...> ], author: "admin", message: "add people")
      iex> length(ids)
      2

  """
  @spec insert(Config.t(), map() | [map()], [insert_opt()]) ::
          {:ok, term()} | {:error, Error.t()}
  def insert(config, document, opts \\ []) do
    path = document_path(config, opts)

    params =
      graph_type_param(opts) ++
        commit_params(opts) ++
        maybe_param(:full_replace, opts[:full_replace]) ++
        maybe_param(:raw_json, opts[:raw_json])

    Client.request(config, :post, path, json: document, params: params, area: :document)
  end

  @doc """
  Inserts documents, returning the response body or raising `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"@id" => "Person/Alice"}])} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Document.insert!(config, %{"@type" => "Person", "name" => "Alice"},
      ...>   author: "admin", message: "add"
      ...> )
      [%{"@id" => "Person/Alice"}]

  """
  @spec insert!(Config.t(), map() | [map()], [insert_opt()]) :: term()
  def insert!(config, document, opts \\ []) do
    case insert(config, document, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Retrieves documents from the database.

  With `:id`, returns a single document. Without `:id`, returns all documents
  (or those of a `:type`). By default TerminusDB returns concatenated JSON; pass
  `as_list: true` to get a JSON array decoded into a list of maps.

  ## Options

  - `:id` — retrieve a specific document by ID.
  - `:type` — retrieve documents of a specific type.
  - `:graph_type` — `:instance` (default) or `:schema`.
  - `:skip` — number of documents to skip (default `0`).
  - `:count` — max number of documents to return.
  - `:as_list` — request a JSON array instead of concatenated JSON.
  - `:unfold` — join referenced documents (default `true`).
  - `:minimized` — minify output (default `true`).
  - `:compress_ids` — compress IDs using prefixes (default `true`).
  - `:organization` — overrides `config.organization`.

  ## Examples

  Get a single document by ID:

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"@id" => "Person/Alice", "name" => "Alice"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, person} = TerminusDB.Document.get(config, id: "Person/Alice", as_list: false)
      iex> person["name"]
      "Alice"

  Get all documents of a type:

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"@id" => "Person/Alice"}, %{"@id" => "Person/Bob"}])} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, docs} = TerminusDB.Document.get(config, type: "Person", as_list: true)
      iex> length(docs)
      2

  """
  @spec get(Config.t(), [get_opt()]) :: {:ok, term()} | {:error, Error.t()}
  def get(config, opts \\ []) do
    path = document_path(config, opts)

    params =
      graph_type_param(opts) ++
        get_params(opts)

    Client.request(config, :get, path, params: params, area: :document)
  end

  @doc """
  Retrieves documents, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"@id" => "Person/Alice"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Document.get!(config, id: "Person/Alice")
      %{"@id" => "Person/Alice"}

  """
  @spec get!(Config.t(), [get_opt()]) :: term()
  def get!(config, opts \\ []) do
    case get(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Queries documents by a template.

  `template` is a map describing the shape of documents to match, e.g.
  `%{"@type" => "Person", "age" => 30}`. TerminusDB returns all documents that
  match the template.

  ## Options

  - `:graph_type` — `:instance` (default) or `:schema`.
  - `:skip`, `:count` — pagination.
  - `:as_list` — return a JSON array.
  - `:organization` — overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"@type" => "Person", "name" => "Alice", "age" => 30}])} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, matches} = TerminusDB.Document.query(config, %{"@type" => "Person", "age" => 30})
      iex> hd(matches)["name"]
      "Alice"

  """
  @spec query(Config.t(), map(), [query_opt()]) :: {:ok, term()} | {:error, Error.t()}
  def query(config, template, opts \\ []) do
    path = document_path(config, opts)

    params =
      graph_type_param(opts) ++
        maybe_param(:skip, opts[:skip]) ++
        maybe_param(:count, opts[:count]) ++
        maybe_param(:as_list, opts[:as_list])

    Client.request(config, :get, path, json: template, params: params, area: :document)
  end

  @doc """
  Queries documents by template, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"name" => "Alice"}])} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Document.query!(config, %{"name" => "Alice"})
      [%{"name" => "Alice"}]

  """
  @spec query!(Config.t(), map(), [query_opt()]) :: term()
  def query!(config, template, opts \\ []) do
    case query(config, template, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Replaces one or more existing documents.

  If a document does not exist, an error is returned unless `create: true` is
  set, in which case it is inserted.

  ## Options

  - `:author`, `:message` — commit metadata (required by the API).
  - `:graph_type` — `:instance` (default) or `:schema`.
  - `:create` — insert if the document does not exist (default `false`).
  - `:raw_json` — treat as untyped JSON (default `false`).
  - `:organization` — overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"@id" => "Person/Alice", "name" => "Alicia"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, updated} = TerminusDB.Document.replace(config,
      ...>   %{"@id" => "Person/Alice", "name" => "Alicia"},
      ...>   author: "admin", message: "rename Alice"
      ...> )
      iex> updated["name"]
      "Alicia"

  """
  @spec replace(Config.t(), map() | [map()], [update_opt()]) ::
          {:ok, term()} | {:error, Error.t()}
  def replace(config, document, opts \\ []) do
    path = document_path(config, opts)

    params =
      graph_type_param(opts) ++
        commit_params(opts) ++
        maybe_param(:create, opts[:create]) ++
        maybe_param(:raw_json, opts[:raw_json])

    Client.request(config, :put, path, json: document, params: params, area: :document)
  end

  @doc """
  Replaces documents, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"@id" => "Person/Alice"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Document.replace!(config, %{"@id" => "Person/Alice", "name" => "Alicia"},
      ...>   author: "admin", message: "rename"
      ...> )
      %{"@id" => "Person/Alice"}

  """
  @spec replace!(Config.t(), map() | [map()], [update_opt()]) :: term()
  def replace!(config, document, opts \\ []) do
    case replace(config, document, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Deletes documents from the database.

  With `:id`, deletes a single document. With `:nuke`, deletes all documents at
  the resource location. Without either, a body containing a list of IDs must
  be posted (not yet supported by this function; use `:id` or `:nuke`).

  ## Options

  - `:author`, `:message` — commit metadata (required by the API).
  - `:graph_type` — `:instance` (default) or `:schema`.
  - `:id` — delete a specific document by ID.
  - `:nuke` — delete all documents (dangerous).
  - `:organization` — overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Document.delete(config,
      ...>   id: "Person/Alice", author: "admin", message: "remove Alice"
      ...> )
      iex> resp["api:status"]
      "api:success"

  """
  @spec delete(Config.t(), [delete_opt()]) :: {:ok, term()} | {:error, Error.t()}
  def delete(config, opts \\ []) do
    path = document_path(config, opts)

    params =
      graph_type_param(opts) ++
        commit_params(opts) ++
        maybe_param(:nuke, opts[:nuke]) ++
        maybe_param(:id, opts[:id])

    Client.request(config, :delete, path, params: params, area: :document)
  end

  @doc """
  Deletes documents, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Document.delete!(config, id: "Person/Alice", author: "a", message: "m")
      %{"api:status" => "api:success"}

  """
  @spec delete!(Config.t(), [delete_opt()]) :: term()
  def delete!(config, opts \\ []) do
    case delete(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Returns a `Stream` of documents, decoded incrementally from the response.

  Uses Req's response streaming (`into: :self`) and the concatenated-JSON
  splitter in `TerminusDB.Streaming` to yield documents one at a time with
  constant memory. Useful for large result sets.

  ## Options

  Accepts the same options as `get/2` (`:type`, `:graph_type`, `:skip`,
  `:count`, etc.).

  ## Examples

      # Stream all Person documents and process one at a time:
      TerminusDB.Document.stream(config, type: "Person")
      |> Stream.each(&IO.inspect/1)
      |> Stream.run()

  """
  @spec stream(Config.t(), [get_opt()]) :: Enumerable.t()
  def stream(config, opts \\ []) do
    path = document_path(config, opts)

    params =
      graph_type_param(opts) ++
        get_params(opts)

    {:ok, resp} =
      Client.request_response(config, :get, path,
        params: params,
        into: :self,
        area: :document
      )

    TerminusDB.Streaming.document_stream(resp)
  end

  # Helpers -------------------------------------------------------------------

  defp commit_params(opts) do
    maybe_param(:author, opts[:author]) ++ maybe_param(:message, opts[:message])
  end

  defp get_params(opts) do
    maybe_param(:id, opts[:id]) ++
      maybe_param(:type, opts[:type]) ++
      maybe_param(:skip, opts[:skip]) ++
      maybe_param(:count, opts[:count]) ++
      maybe_param(:as_list, opts[:as_list]) ++
      maybe_param(:unfold, opts[:unfold]) ++
      maybe_param(:minimized, opts[:minimized]) ++
      maybe_param(:compress_ids, opts[:compress_ids])
  end

  defp maybe_param(_name, nil), do: []
  defp maybe_param(_name, false), do: []
  defp maybe_param(name, true), do: [{name, true}]
  defp maybe_param(name, value), do: [{name, value}]
end
