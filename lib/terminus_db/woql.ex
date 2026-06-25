defmodule TerminusDB.WOQL do
  @moduledoc """
  A functional builder DSL for WOQL (Web Object Query Language).

  WOQL is TerminusDB's Datalog-based query language. This module provides a
  small but solid set of composable functions that build a `TerminusDB.WOQL.Query`
  struct, which can be serialized to the JSON-LD wire format via `to_jsonld/1`
  and executed via `TerminusDB.WOQL.execute/3`.

  This is WOQL DSL v0.1 - a focused subset covering the most common patterns.
  Future releases will extend the vocabulary.

  ## Design

  The DSL is purely functional (no macros). Each function returns a
  `%WOQL.Query{}` struct and composes by nesting, mirroring the recommended
  functional WOQL style. Variables are plain strings using the `v:Name`
  convention.

  ## Supported vocabulary (v0.1)

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `triple/3` | `Triple` |
  | `and_/1` | `And` |
  | `or_/1` | `Or` |
  | `eq/2` | `Equals` |
  | `select/2` | `Select` |
  | `read_document/2` | `ReadDocument` |
  | `type_of/2` | `TypeOf` |

  ## Quick start

      import TerminusDB.WOQL

      query =
        and_([
          triple("v:Person", "rdf:type", "@schema:Person"),
          triple("v:Person", "name", "v:Name")
        ])

      jsonld = TerminusDB.WOQL.to_jsonld(query)

      # Execute against a database
      config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      config = TerminusDB.Config.with_database(config, "mydb")
      {:ok, result} = TerminusDB.WOQL.execute(config, query)

  """

  alias TerminusDB.{Client, Config, Error}
  alias TerminusDB.Client.Params

  defstruct [:op, :args]

  @type t :: %__MODULE__{op: atom(), args: [term()]}

  @type woql_var :: String.t()
  @type woql_node :: String.t() | woql_var()
  @type value :: String.t() | woql_var() | number() | boolean() | map()

  # --------------------------------------------------------------------------
  # Query builders
  # --------------------------------------------------------------------------

  @doc """
  Builds a `Triple` pattern: subject, predicate, object.

  Any argument can be a variable (`"v:Name"`) or a constant.

  ## Examples

      iex> q = TerminusDB.WOQL.triple("v:Person", "name", "v:Name")
      iex> q.op
      :triple

  """
  @spec triple(woql_node(), woql_node(), value()) :: t()
  def triple(subject, predicate, object) do
    %__MODULE__{op: :triple, args: [subject, predicate, object]}
  end

  @doc """
  Builds an `And` conjunction of sub-queries.

  ## Examples

      iex> q = TerminusDB.WOQL.and_([
      ...>   TerminusDB.WOQL.triple("v:S", "rdf:type", "v:T"),
      ...>   TerminusDB.WOQL.eq("v:T", "Person")
      ...> ])
      iex> q.op
      :and

  """
  @spec and_([t()]) :: t()
  def and_(queries) when is_list(queries) do
    %__MODULE__{op: :and, args: queries}
  end

  @doc """
  Builds an `Or` disjunction of sub-queries.

  ## Examples

      iex> q = TerminusDB.WOQL.or_([
      ...>   TerminusDB.WOQL.eq("v:Name", "Alice"),
      ...>   TerminusDB.WOQL.eq("v:Name", "Bob")
      ...> ])
      iex> q.op
      :or

  """
  @spec or_([t()]) :: t()
  def or_(queries) when is_list(queries) do
    %__MODULE__{op: :or, args: queries}
  end

  @doc """
  Builds an `Equals` unification: left equals right.

  ## Examples

      iex> q = TerminusDB.WOQL.eq("v:Name", "Alice")
      iex> q.op
      :eq

  """
  @spec eq(value(), value()) :: t()
  def eq(left, right) do
    %__MODULE__{op: :eq, args: [left, right]}
  end

  @doc """
  Builds a `Select` that projects the given variables from a sub-query.

  `vars` is a list of variable names (e.g. `["v:Name", "v:Person"]`).

  ## Examples

      iex> q = TerminusDB.WOQL.select(["v:Name"],
      ...>   TerminusDB.WOQL.and_([
      ...>     TerminusDB.WOQL.triple("v:Person", "name", "v:Name")
      ...>   ])
      ...> )
      iex> q.op
      :select

  """
  @spec select([woql_var()], t()) :: t()
  def select(vars, query) when is_list(vars) and is_struct(query, __MODULE__) do
    %__MODULE__{op: :select, args: [vars, query]}
  end

  @doc """
  Builds a `ReadDocument` that reads a document by ID into a variable.

  ## Examples

      iex> q = TerminusDB.WOQL.read_document("Person/Alice", "v:Doc")
      iex> q.op
      :read_document

  """
  @spec read_document(String.t(), woql_var()) :: t()
  def read_document(id, var) do
    %__MODULE__{op: :read_document, args: [id, var]}
  end

  @doc """
  Builds a `TypeOf` that unifies the type of a node with a variable.

  ## Examples

      iex> q = TerminusDB.WOQL.type_of("v:Person", "v:Type")
      iex> q.op
      :type_of

  """
  @spec type_of(woql_node(), woql_var()) :: t()
  def type_of(node, var) do
    %__MODULE__{op: :type_of, args: [node, var]}
  end

  # --------------------------------------------------------------------------
  # Serialization
  # --------------------------------------------------------------------------

  @doc """
  Serializes a `WOQL.Query` to the JSON-LD wire format expected by the
  `/api/woql` endpoint.

  ## Examples

      iex> q = TerminusDB.WOQL.triple("v:S", "name", "v:N")
      iex> jsonld = TerminusDB.WOQL.to_jsonld(q)
      iex> jsonld["@type"]
      "Triple"

  """
  @spec to_jsonld(t()) :: map()
  def to_jsonld(%__MODULE__{} = query) do
    encode(query)
  end

  @doc """
  Deserializes a JSON-LD WOQL query back into a `WOQL.Query` struct.

  ## Examples

      iex> jsonld = %{"@type" => "Triple", "subject" => %{"@type" => "NodeValue", "variable" => "S"}, "predicate" => %{"@type" => "NodeValue", "node" => "name"}, "object" => %{"@type" => "DataValue", "variable" => "N"}}
      iex> q = TerminusDB.WOQL.from_jsonld(jsonld)
      iex> q.op
      :triple

  """
  @spec from_jsonld(map()) :: t()
  def from_jsonld(%{} = jsonld) do
    decode(jsonld)
  end

  # --------------------------------------------------------------------------
  # Execution
  # --------------------------------------------------------------------------

  @doc """
  Executes a WOQL query against the database scoped in `config`.

  Returns `{:ok, result}` where `result` is a map containing `bindings` (a list
  of maps, one per solution), or `{:error, TerminusDB.Error.t()}`.

  ## Options

  - `:author` - commit author (for write queries).
  - `:message` - commit message (for write queries).
  - `:all_witnesses` - check for all errors (default `false`).
  - `:organization` - overrides `config.organization`.
  - `:repo` - overrides `config.repo`.
  - `:branch` - overrides `config.branch`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"bindings" => [%{"Name" => "Alice"}]})}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> q = TerminusDB.WOQL.select(["v:Name"],
      ...>   TerminusDB.WOQL.and_([TerminusDB.WOQL.triple("v:P", "name", "v:Name")])
      ...> )
      iex> {:ok, result} = TerminusDB.WOQL.execute(config, q)
      iex> result["bindings"]
      [%{"Name" => "Alice"}]

  """
  @spec execute(Config.t(), t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def execute(config, %__MODULE__{} = query, opts \\ []) do
    org = opts[:organization] || config.organization

    db =
      config.database ||
        raise Error, reason: :http, message: "no database scoped in config"

    repo = opts[:repo] || config.repo
    branch = opts[:branch] || config.branch
    path = "woql/#{org}/#{db}/#{repo}/branch/#{branch}"

    body =
      %{"query" => to_jsonld(query)}
      |> Params.maybe_put("commit_info", build_commit_info(opts))
      |> Params.maybe_put("all_witnesses", opts[:all_witnesses])

    Client.request(config, :post, path, json: body, area: :woql)
  end

  @doc """
  Executes a WOQL query, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"bindings" => []})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> q = TerminusDB.WOQL.triple("v:S", "p", "v:O")
      iex> TerminusDB.WOQL.execute!(config, q)
      %{"bindings" => []}

  """
  @spec execute!(Config.t(), t(), keyword()) :: map()
  def execute!(config, query, opts \\ []) do
    case execute(config, query, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  # --------------------------------------------------------------------------
  # Internal: JSON-LD encoding
  #
  # The TerminusDB WOQL JSON-LD format uses short type names ("Triple", "And",
  # etc.) and wraps values in NodeValue/DataValue objects:
  #
  #   Variables: {"@type": "NodeValue", "variable": "Name"} (for nodes)
  #              {"@type": "DataValue", "variable": "Name"} (for data values)
  #   Constants: {"@type": "NodeValue", "node": "rdf:type"} (for node/IRI strings)
  #              {"@type": "DataValue", "data": {"@type": "xsd:string", "@value": ...}}
  #                (for literal strings, numbers, booleans)
  # --------------------------------------------------------------------------

  defp encode(%__MODULE__{op: :triple, args: [s, p, o]}) do
    %{
      "@type" => "Triple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o)
    }
  end

  defp encode(%__MODULE__{op: :and, args: queries}) do
    %{
      "@type" => "And",
      "and" => Enum.map(queries, &encode/1)
    }
  end

  defp encode(%__MODULE__{op: :or, args: queries}) do
    %{
      "@type" => "Or",
      "or" => Enum.map(queries, &encode/1)
    }
  end

  defp encode(%__MODULE__{op: :eq, args: [left, right]}) do
    %{
      "@type" => "Equals",
      "left" => encode_data(left),
      "right" => encode_data(right)
    }
  end

  defp encode(%__MODULE__{op: :select, args: [vars, query]}) do
    %{
      "@type" => "Select",
      "variables" => Enum.map(vars, &encode_select_var/1),
      "query" => encode(query)
    }
  end

  defp encode(%__MODULE__{op: :read_document, args: [id, var]}) do
    %{
      "@type" => "ReadDocument",
      "document" => encode_node(id),
      "identifier" => encode_value(var)
    }
  end

  defp encode(%__MODULE__{op: :type_of, args: [node, var]}) do
    %{
      "@type" => "TypeOf",
      "value" => encode_value(node),
      "type" => encode_node(var)
    }
  end

  # Encode a node value: variables become NodeValue with "variable",
  # constants become NodeValue with "node".
  defp encode_node(var) when is_binary(var) and binary_part(var, 0, 2) == "v:" do
    %{"@type" => "NodeValue", "variable" => String.slice(var, 2..-1//1)}
  end

  defp encode_node(value) when is_binary(value) do
    %{"@type" => "NodeValue", "node" => value}
  end

  # Encode a value (triple object, type_of value): variables become DataValue
  # with "variable", constant strings become NodeValue with "node" (IRIs),
  # numbers/booleans become DataValue with xsd-typed data.
  defp encode_value(var) when is_binary(var) and binary_part(var, 0, 2) == "v:" do
    %{"@type" => "DataValue", "variable" => String.slice(var, 2..-1//1)}
  end

  defp encode_value(value) when is_binary(value) do
    %{"@type" => "NodeValue", "node" => value}
  end

  defp encode_value(value) when is_integer(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:integer", "@value" => value}}
  end

  defp encode_value(value) when is_float(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:decimal", "@value" => value}}
  end

  defp encode_value(value) when is_boolean(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:boolean", "@value" => value}}
  end

  defp encode_value(value) when is_map(value), do: value

  # Encode a data value for Equals: literals must be wrapped in DataValue with
  # the correct xsd type. Variables use DataValue with "variable".
  defp encode_data(var) when is_binary(var) and binary_part(var, 0, 2) == "v:" do
    %{"@type" => "DataValue", "variable" => String.slice(var, 2..-1//1)}
  end

  defp encode_data(value) when is_binary(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:string", "@value" => value}}
  end

  defp encode_data(value) when is_integer(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:integer", "@value" => value}}
  end

  defp encode_data(value) when is_float(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:decimal", "@value" => value}}
  end

  defp encode_data(value) when is_boolean(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:boolean", "@value" => value}}
  end

  # Select variables are bare variable name strings (without v: prefix).
  defp encode_select_var(var) when is_binary(var) and binary_part(var, 0, 2) == "v:" do
    String.slice(var, 2..-1//1)
  end

  defp encode_select_var(var) when is_binary(var), do: var

  # --------------------------------------------------------------------------
  # Internal: JSON-LD decoding
  # --------------------------------------------------------------------------

  defp decode(%{"@type" => "Triple"} = m) do
    triple(decode_node(m["subject"]), decode_node(m["predicate"]), decode_value(m["object"]))
  end

  defp decode(%{"@type" => "And", "and" => queries}) do
    and_(Enum.map(queries, &decode/1))
  end

  defp decode(%{"@type" => "Or", "or" => queries}) do
    or_(Enum.map(queries, &decode/1))
  end

  defp decode(%{"@type" => "Equals"} = m) do
    eq(decode_data(m["left"]), decode_data(m["right"]))
  end

  defp decode(%{"@type" => "Select", "variables" => vars, "query" => query}) do
    select(Enum.map(vars, &decode_select_var/1), decode(query))
  end

  defp decode(%{"@type" => "ReadDocument"} = m) do
    read_document(decode_node(m["document"]), decode_value(m["identifier"]))
  end

  defp decode(%{"@type" => "TypeOf"} = m) do
    type_of(decode_value(m["value"]), decode_node(m["type"]))
  end

  defp decode_node(%{"@type" => "NodeValue", "variable" => name}) do
    "v:#{name}"
  end

  defp decode_node(%{"@type" => "NodeValue", "node" => node}) do
    node
  end

  defp decode_node(value), do: value

  defp decode_value(%{"@type" => "DataValue", "variable" => name}) do
    "v:#{name}"
  end

  defp decode_value(%{"@type" => "NodeValue", "variable" => name}) do
    "v:#{name}"
  end

  defp decode_value(%{"@type" => "NodeValue", "node" => node}) do
    node
  end

  defp decode_value(%{"@type" => "DataValue", "data" => %{"@value" => value}}) do
    value
  end

  defp decode_value(value), do: value

  defp decode_data(%{"@type" => "DataValue", "variable" => name}) do
    "v:#{name}"
  end

  defp decode_data(%{"@type" => "DataValue", "data" => %{"@value" => value}}) do
    value
  end

  defp decode_data(value), do: value

  defp decode_select_var(name) when is_binary(name), do: "v:#{name}"

  defp build_commit_info(opts) do
    author = opts[:author]
    message = opts[:message]

    if author || message do
      %{"author" => author || "", "message" => message || ""}
    end
  end
end
