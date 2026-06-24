defmodule TerminusDB.Schema do
  @moduledoc """
  Schema frame API for TerminusDB.

  Wraps the `/api/schema` endpoint, which returns the class frame for a class or
  all classes for a database's schema. A "frame" is a JSON-LD description of a
  schema class: its properties, types, key strategy, and documentation.

  All functions require a `TerminusDB.Config` scoped to a database (via
  `TerminusDB.Config.with_database/2`).

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")
        |> TerminusDB.Config.with_database("mydb")

      # Get the frame for a specific class
      {:ok, frame} = TerminusDB.Schema.frame(config, "Person")
      # => %{"@type" => "Class", "name" => "xsd:string", ...}

      # Get all class frames
      {:ok, all} = TerminusDB.Schema.all(config)
      # => %{"Person" => %{"@type" => "Class", ...}, "Room" => %{...}}

  """

  alias TerminusDB.{Client, Config, Error}
  alias TerminusDB.Client.Params

  @type frame_opt ::
          {:compress_ids, boolean()}
          | {:expand_abstract, boolean()}
          | {:organization, String.t()}

  defp schema_path(config, opts) do
    "schema/#{Client.resource_path(config, opts)}"
  end

  @doc """
  Returns the class frame for a specific class `class_name`, or all class frames
  if `class_name` is `nil`.

  ## Options

  - `:compress_ids` — compress the URLs returned using prefixes (default `true`).
  - `:expand_abstract` — expand abstract classes into lists of concrete classes
    in frame options (default `true`).
  - `:organization` — overrides `config.organization`.

  ## Examples

  Get the frame for a specific class:

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"@type" => "Class", "name" => "xsd:string"})}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, frame} = TerminusDB.Schema.frame(config, "Person")
      iex> frame["name"]
      "xsd:string"

  Get all class frames (pass `nil` or omit `class_name`):

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"Person" => %{"@type" => "Class"}, "Room" => %{"@type" => "Class"}})}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, all} = TerminusDB.Schema.frame(config)
      iex> Map.keys(all) |> Enum.sort()
      ["Person", "Room"]

  """
  @spec frame(Config.t(), String.t() | nil, [frame_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def frame(config, class_name \\ nil, opts \\ []) do
    path = schema_path(config, opts)

    params =
      Params.bool_param(:compress_ids, opts[:compress_ids]) ++
        Params.bool_param(:expand_abstract, opts[:expand_abstract])

    path =
      if class_name do
        "#{path}/#{class_name}"
      else
        path
      end

    Client.request(config, :get, path, params: params, area: :document)
  end

  @doc """
  Returns the class frame, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"@type" => "Class", "name" => "xsd:string"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Schema.frame!(config, "Person")
      %{"@type" => "Class", "name" => "xsd:string"}

  """
  @spec frame!(Config.t(), String.t() | nil, [frame_opt()]) :: map()
  def frame!(config, class_name \\ nil, opts \\ []) do
    case frame(config, class_name, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Returns all class frames for the database's schema.

  Equivalent to `frame(config, nil, opts)`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"Person" => %{"@type" => "Class"}})}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, all} = TerminusDB.Schema.all(config)
      iex> Map.keys(all)
      ["Person"]

  """
  @spec all(Config.t(), [frame_opt()]) :: {:ok, map()} | {:error, Error.t()}
  def all(config, opts \\ []), do: frame(config, nil, opts)

  @doc """
  Returns all class frames, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"Person" => %{"@type" => "Class"}})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Schema.all!(config)
      %{"Person" => %{"@type" => "Class"}}

  """
  @spec all!(Config.t(), [frame_opt()]) :: map()
  def all!(config, opts \\ []), do: frame!(config, nil, opts)

  # For boolean params where `false` is a meaningful value (not a default to
  # omit), we pass it through explicitly via Params.bool_param/2.
end
