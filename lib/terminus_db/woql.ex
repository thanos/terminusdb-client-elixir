defmodule TerminusDB.WOQL do
  @moduledoc """
  A functional builder DSL for WOQL (Web Object Query Language).

  WOQL is TerminusDB's Datalog-based query language. This module provides a
  comprehensive set of ~70 composable functions that build a `TerminusDB.WOQL.Query`
  struct, which can be serialized to the JSON-LD wire format via `to_jsonld/1`
  and executed via `TerminusDB.WOQL.execute/3`.

  This is WOQL DSL v0.2 (ADR-0008) — covering the core and important-advanced
  vocabulary (Tier 1+2) matching the Python/JS clients.

  ## Design

  The DSL is purely functional (no macros). Each function returns a
  `%WOQL.Query{}` struct and composes by nesting, mirroring the recommended
  functional WOQL style. Variables are plain strings using the `v:Name`
  convention.

  The JSON-LD encoder uses four value-wrapper types matching the Python/JS
  clients: `NodeValue` (nodes/IRIs), `Value` (generic values), `DataValue`
  (literal data), and `ArithmeticValue` (arithmetic operands). Use `iri/1` to
  explicitly mark a string as an IRI in triple object position (string objects
  default to `xsd:string` literals).

  ## Supported vocabulary (v0.2)

  ### Logical combinators

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `and_/1` | `And` |
  | `or_/1` | `Or` |
  | `not_/1` | `Not` |
  | `opt/1` (alias `optional/1`) | `Optional` |
  | `once/1` | `Once` |
  | `immediately/1` | `Immediately` |

  ### Query modifiers

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `select/2` | `Select` |
  | `distinct/2` | `Distinct` |
  | `limit/2` | `Limit` |
  | `start/2` | `Start` |
  | `order_by/2` | `OrderBy` |
  | `group_by/4` | `GroupBy` |
  | `count/2` | `Count` |
  | `collect/3` | `Collect` |
  | `star/0`, `all/0` | `Triple` (shortcut) |

  ### Graph patterns

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `triple/3` | `Triple` |
  | `quad/4` | `Triple` + `graph` |
  | `added_triple/3`, `added_quad/4` | `AddedTriple` |
  | `removed_triple/3`, `removed_quad/4` | `DeletedTriple` |
  | `add_triple/3`, `add_quad/4` | `AddTriple` |
  | `delete_triple/3`, `delete_quad/4` | `DeleteTriple` |
  | `update_triple/3`, `update_quad/4` | `And` (macro) |

  ### Comparison

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `eq/2` | `Equals` |
  | `less/2` | `Less` |
  | `greater/2` | `Greater` |
  | `gte/2` | `Gte` |
  | `lte/2` | `Lte` |
  | `like/3` | `Like` |

  ### Schema ops

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `type_of/2` | `TypeOf` |
  | `isa/2` | `IsA` |
  | `sub/2` (alias `subsumption/2`) | `Subsumption` |
  | `cast/3` (alias `typecast/3`) | `Typecast` |

  ### Arithmetic

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `eval/2` | `Eval` |
  | `plus/1`, `minus/1`, `times/1`, `divide/1` | `Plus`/`Minus`/`Times`/`Divide` |
  | `div/1` | `Div` |
  | `exp/2` | `Exp` |
  | `floor/1` | `Floor` |
  | `sum/2` | `Sum` |

  ### String ops

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `concat/2` (alias `concatenate/2`) | `Concatenate` |
  | `join/3` | `Join` |
  | `substr/5` (alias `substring/5`) | `Substring` |
  | `trim/2` | `Trim` |
  | `upper/2` | `Upper` |
  | `lower/2` | `Lower` |
  | `pad/4` | `Pad` |
  | `split/3` | `Split` |
  | `length/2` | `Length` |
  | `regexp/3` | `Regexp` |

  ### List / Set / Dict ops

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `dot/3` | `Dot` |
  | `member/2` | `Member` |
  | `slice/4` | `Slice` |
  | `set_difference/3` | `SetDifference` |
  | `set_intersection/3` | `SetIntersection` |
  | `set_union/3` | `SetUnion` |
  | `set_member/2` | `SetMember` |
  | `list_to_set/2` | `ListToSet` |

  ### Path / navigation

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `path/3`, `path/4` | `Path` |

  Path patterns accept both string patterns (`path("v:S", "friend*", "v:O")`)
  and structured builders via `TerminusDB.WOQL.Path` (`path_star/1`,
  `path_plus/1`, `path_times/3`, `path_seq/1`, `path_or/1`, `path_inverse/1`,
  `path_pred/1`, `path_any/0`).

  ### ID generation

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `unique/3` | `HashKey` |
  | `idgen/3` (alias `idgenerator/3`) | `LexicalKey` |
  | `idgen_random/2` (alias `random_idgen/2`) | `RandomKey` |

  ### Documents

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `read_document/2` | `ReadDocument` |
  | `insert_document/2` | `InsertDocument` |
  | `update_document/2` | `UpdateDocument` |
  | `delete_document/1` | `DeleteDocument` |

  ### Graph context

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `using/2` | `Using` |
  | `from/2` | `From` |
  | `into/2` | `Into` |
  | `comment/2` | `Comment` |

  ### Graph meta

  | Function | WOQL JSON-LD type |
  | --- | --- |
  | `size/2` | `Size` |
  | `triple_count/2` | `TripleCount` |

  ### Literal / value helpers

  | Function | Description |
  | --- | --- |
  | `var/1` | Wraps a name as `"v:Name"` |
  | `iri/1` | Wraps a string as a `NodeValue` IRI |
  | `string/1` | Wraps as `xsd:string` literal |
  | `boolean/1` | Wraps as `xsd:boolean` literal |
  | `datetime/1` | Wraps as `xsd:dateTime` literal |
  | `date/1` | Wraps as `xsd:date` literal |
  | `literal/2` | Generic typed literal |
  | `true_/0` | `True` constant |

  ## Quick start

      import TerminusDB.WOQL

      query =
        and_([
          triple("v:Person", "rdf:type", iri("@schema:Person")),
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
  alias TerminusDB.WOQL.{Decoder, Encoder, Literal, Path}

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

  @doc """
  Wraps a string as a `NodeValue` IRI — use for triple objects that should be
  treated as IRIs rather than string literals.

  ## Examples

      iex> TerminusDB.WOQL.iri("@schema:Person")
      %{"@type" => "NodeValue", "node" => "@schema:Person"}

  """
  @spec iri(String.t()) :: map()
  def iri(node), do: Literal.iri(node)

  # --------------------------------------------------------------------------
  # Literal / value helpers
  # --------------------------------------------------------------------------

  @doc """
  Wraps a name as a WOQL variable string (`"v:Name"`).

  ## Examples

      iex> TerminusDB.WOQL.var("Person")
      "v:Person"

  """
  @spec var(String.t()) :: String.t()
  def var(name), do: Literal.var(name)

  @doc """
  Wraps a string as an `xsd:string` literal dict.

  ## Examples

      iex> TerminusDB.WOQL.string("hello")
      %{"@type" => "xsd:string", "@value" => "hello"}

  """
  @spec string(String.t()) :: map()
  def string(value), do: Literal.string(value)

  @doc """
  Wraps a boolean as an `xsd:boolean` literal dict.

  ## Examples

      iex> TerminusDB.WOQL.boolean(true)
      %{"@type" => "xsd:boolean", "@value" => true}

  """
  @spec boolean(boolean()) :: map()
  def boolean(value), do: Literal.boolean(value)

  @doc """
  Wraps a `DateTime`, `NaiveDateTime`, or ISO 8601 string as an
  `xsd:dateTime` literal dict.

  ## Examples

      iex> TerminusDB.WOQL.datetime("2026-01-15T10:30:00Z")
      %{"@type" => "xsd:dateTime", "@value" => "2026-01-15T10:30:00Z"}

  """
  @spec datetime(DateTime.t() | NaiveDateTime.t() | String.t()) :: map()
  def datetime(value), do: Literal.datetime(value)

  @doc """
  Wraps a `Date` or ISO 8601 string as an `xsd:date` literal dict.

  ## Examples

      iex> TerminusDB.WOQL.date("2026-01-15")
      %{"@type" => "xsd:date", "@value" => "2026-01-15"}

  """
  @spec date(Date.t() | String.t()) :: map()
  def date(value), do: Literal.date(value)

  @doc """
  Wraps a value as a typed literal dict. The type is prefixed with `xsd:` if it
  does not already contain a colon.

  ## Examples

      iex> TerminusDB.WOQL.literal("42", "integer")
      %{"@type" => "xsd:integer", "@value" => "42"}

  """
  @spec literal(term(), String.t()) :: map()
  def literal(value, type), do: Literal.literal(value, type)

  @doc """
  Builds a `True` constant query.

  ## Examples

      iex> q = TerminusDB.WOQL.true_()
      iex> q.op
      :true

  """
  @spec true_ :: t()
  def true_, do: %__MODULE__{op: true, args: []}

  # --------------------------------------------------------------------------
  # Logical combinators
  # --------------------------------------------------------------------------

  @doc """
  Builds a `Not` negation of a sub-query.

  ## Examples

      iex> q = TerminusDB.WOQL.not_(TerminusDB.WOQL.eq("v:N", "Alice"))
      iex> q.op
      :not

  """
  @spec not_(t()) :: t()
  def not_(query) when is_struct(query, __MODULE__) do
    %__MODULE__{op: :not, args: [query]}
  end

  @doc """
  Builds an `Optional` wrapper — the sub-query is allowed to fail without
  invalidating the enclosing query.

  ## Examples

      iex> q = TerminusDB.WOQL.opt(TerminusDB.WOQL.triple("v:S", "p", "v:O"))
      iex> q.op
      :opt

  """
  @spec opt(t()) :: t()
  def opt(query) when is_struct(query, __MODULE__) do
    %__MODULE__{op: :opt, args: [query]}
  end

  @doc """
  Alias for `opt/1`.
  """
  @spec optional(t()) :: t()
  def optional(query), do: opt(query)

  @doc """
  Builds a `Once` — obtain only one result from the sub-query.

  ## Examples

      iex> q = TerminusDB.WOQL.once(TerminusDB.WOQL.triple("v:S", "p", "v:O"))
      iex> q.op
      :once

  """
  @spec once(t()) :: t()
  def once(query) when is_struct(query, __MODULE__) do
    %__MODULE__{op: :once, args: [query]}
  end

  @doc """
  Builds an `Immediately` — run side-effects without backtracking.

  ## Examples

      iex> q = TerminusDB.WOQL.immediately(TerminusDB.WOQL.triple("v:S", "p", "v:O"))
      iex> q.op
      :immediately

  """
  @spec immediately(t()) :: t()
  def immediately(query) when is_struct(query, __MODULE__) do
    %__MODULE__{op: :immediately, args: [query]}
  end

  # --------------------------------------------------------------------------
  # Query modifiers
  # --------------------------------------------------------------------------

  @doc """
  Builds a `Distinct` — returns distinct solutions for the given variables.

  ## Examples

      iex> q = TerminusDB.WOQL.distinct(["v:Name"], TerminusDB.WOQL.triple("v:P", "name", "v:Name"))
      iex> q.op
      :distinct

  """
  @spec distinct([woql_var()], t()) :: t()
  def distinct(vars, query) when is_list(vars) and is_struct(query, __MODULE__) do
    %__MODULE__{op: :distinct, args: [vars, query]}
  end

  @doc """
  Builds a `Limit` — maximum number of results.

  ## Examples

      iex> q = TerminusDB.WOQL.limit(10, TerminusDB.WOQL.triple("v:S", "p", "v:O"))
      iex> q.op
      :limit

  """
  @spec limit(non_neg_integer(), t()) :: t()
  def limit(n, query) when is_integer(n) and n >= 0 and is_struct(query, __MODULE__) do
    %__MODULE__{op: :limit, args: [n, query]}
  end

  @doc """
  Builds a `Start` — offset (start index) for results.

  ## Examples

      iex> q = TerminusDB.WOQL.start(5, TerminusDB.WOQL.triple("v:S", "p", "v:O"))
      iex> q.op
      :start

  """
  @spec start(non_neg_integer(), t()) :: t()
  def start(n, query) when is_integer(n) and n >= 0 and is_struct(query, __MODULE__) do
    %__MODULE__{op: :start, args: [n, query]}
  end

  @doc """
  Builds an `OrderBy` — orders results by the given variables.

  Accepts both tuple-list and keyword-list forms:

      # Tuple list
      TerminusDB.WOQL.order_by([{"v:Time", :asc}, {"v:Name", :desc}], query)

      # Keyword list
      TerminusDB.WOQL.order_by([time: :asc, name: :desc], query)

  ## Examples

      iex> q = TerminusDB.WOQL.order_by([{"v:Name", :asc}], TerminusDB.WOQL.triple("v:S", "name", "v:Name"))
      iex> q.op
      :order_by

      iex> q2 = TerminusDB.WOQL.order_by([name: :desc], TerminusDB.WOQL.triple("v:S", "name", "v:Name"))
      iex> q2.op
      :order_by

  """
  @spec order_by([{String.t(), :asc | :desc}] | keyword(), t()) :: t()
  def order_by(specs, query) when is_list(specs) and is_struct(query, __MODULE__) do
    %__MODULE__{op: :order_by, args: [normalize_order_specs(specs), query]}
  end

  @doc """
  Builds a `GroupBy` — groups sub-query results by `vars` using `template`,
  binding into `grouped`.

  ## Examples

      iex> q = TerminusDB.WOQL.group_by(["v:Type"], "v:Template", "v:Grouped",
      ...>   TerminusDB.WOQL.triple("v:S", "rdf:type", "v:Type"))
      iex> q.op
      :group_by

  """
  @spec group_by([woql_var()], value(), value(), t()) :: t()
  def group_by(vars, template, grouped, query)
      when is_list(vars) and is_struct(query, __MODULE__) do
    %__MODULE__{op: :group_by, args: [vars, template, grouped, query]}
  end

  @doc """
  Builds a `Count` — counts solutions of the sub-query and binds to `countvar`.

  ## Examples

      iex> q = TerminusDB.WOQL.count("v:N", TerminusDB.WOQL.triple("v:S", "p", "v:O"))
      iex> q.op
      :count

  """
  @spec count(woql_var(), t()) :: t()
  def count(countvar, query) when is_binary(countvar) and is_struct(query, __MODULE__) do
    %__MODULE__{op: :count, args: [countvar, query]}
  end

  @doc """
  Builds a `Collect` — collects all solutions into a list.

  ## Examples

      iex> q = TerminusDB.WOQL.collect("v:Template", "v:Into",
      ...>   TerminusDB.WOQL.triple("v:S", "p", "v:O"))
      iex> q.op
      :collect

  """
  @spec collect(value(), value(), t()) :: t()
  def collect(template, into, query) when is_struct(query, __MODULE__) do
    %__MODULE__{op: :collect, args: [template, into, query]}
  end

  @doc """
  Builds a `star` query — selects everything as triples with default
  variables `v:Subject`, `v:Predicate`, `v:Object`.

  ## Examples

      iex> q = TerminusDB.WOQL.star()
      iex> q.op
      :triple

  """
  @spec star() :: t()
  def star, do: triple("v:Subject", "v:Predicate", "v:Object")

  @doc """
  Alias for `star/0`.
  """
  @spec all() :: t()
  def all, do: star()

  # --------------------------------------------------------------------------
  # Graph patterns
  # --------------------------------------------------------------------------

  @doc """
  Builds a `Quad` pattern: subject, predicate, object, graph.

  Quads reuse the `Triple` JSON-LD type with an added `graph` field.

  ## Examples

      iex> q = TerminusDB.WOQL.quad("v:S", "name", "v:N", "instance")
      iex> q.op
      :quad

  """
  @spec quad(woql_node(), woql_node(), value(), String.t()) :: t()
  def quad(s, p, o, graph) do
    %__MODULE__{op: :quad, args: [s, p, o, graph]}
  end

  @doc """
  Builds an `AddedTriple` — a triple added in the current commit.

  ## Examples

      iex> q = TerminusDB.WOQL.added_triple("v:S", "name", "v:N")
      iex> q.op
      :added_triple

  """
  @spec added_triple(woql_node(), woql_node(), value()) :: t()
  def added_triple(s, p, o) do
    %__MODULE__{op: :added_triple, args: [s, p, o]}
  end

  @doc """
  Builds a `DeletedTriple` — a triple removed in the current commit.

  ## Examples

      iex> q = TerminusDB.WOQL.removed_triple("v:S", "name", "v:N")
      iex> q.op
      :removed_triple

  """
  @spec removed_triple(woql_node(), woql_node(), value()) :: t()
  def removed_triple(s, p, o) do
    %__MODULE__{op: :removed_triple, args: [s, p, o]}
  end

  @doc """
  Builds an `AddedTriple` with a graph — a quad added in the current commit.

  ## Examples

      iex> q = TerminusDB.WOQL.added_quad("v:S", "name", "v:N", "instance")
      iex> q.op
      :added_quad

  """
  @spec added_quad(woql_node(), woql_node(), value(), String.t()) :: t()
  def added_quad(s, p, o, graph) do
    %__MODULE__{op: :added_quad, args: [s, p, o, graph]}
  end

  @doc """
  Builds a `DeletedTriple` with a graph — a quad removed in the current commit.

  ## Examples

      iex> q = TerminusDB.WOQL.removed_quad("v:S", "name", "v:N", "instance")
      iex> q.op
      :removed_quad

  """
  @spec removed_quad(woql_node(), woql_node(), value(), String.t()) :: t()
  def removed_quad(s, p, o, graph) do
    %__MODULE__{op: :removed_quad, args: [s, p, o, graph]}
  end

  @doc """
  Builds an `AddTriple` — adds triples matching `[S, P, O]`.

  ## Examples

      iex> q = TerminusDB.WOQL.add_triple("v:S", "name", "Alice")
      iex> q.op
      :add_triple

  """
  @spec add_triple(woql_node(), woql_node(), value()) :: t()
  def add_triple(s, p, o) do
    %__MODULE__{op: :add_triple, args: [s, p, o]}
  end

  @doc """
  Builds a `DeleteTriple` — deletes triples matching `[S, P, O]`.

  ## Examples

      iex> q = TerminusDB.WOQL.delete_triple("v:S", "name", "v:O")
      iex> q.op
      :delete_triple

  """
  @spec delete_triple(woql_node(), woql_node(), value()) :: t()
  def delete_triple(s, p, o) do
    %__MODULE__{op: :delete_triple, args: [s, p, o]}
  end

  @doc """
  Builds an `AddTriple` with a graph — adds quads.

  ## Examples

      iex> q = TerminusDB.WOQL.add_quad("v:S", "name", "Alice", "instance")
      iex> q.op
      :add_quad

  """
  @spec add_quad(woql_node(), woql_node(), value(), String.t()) :: t()
  def add_quad(s, p, o, graph) do
    %__MODULE__{op: :add_quad, args: [s, p, o, graph]}
  end

  @doc """
  Builds a `DeleteTriple` with a graph — deletes quads.

  ## Examples

      iex> q = TerminusDB.WOQL.delete_quad("v:S", "name", "v:O", "instance")
      iex> q.op
      :delete_quad

  """
  @spec delete_quad(woql_node(), woql_node(), value(), String.t()) :: t()
  def delete_quad(s, p, o, graph) do
    %__MODULE__{op: :delete_quad, args: [s, p, o, graph]}
  end

  @doc """
  Composes an update: optionally delete any existing triple, then add the new
  one. Equivalent to `and_([opt(delete_triple(s, p, "v:OldObject")), add_triple(s, p, o)])`.

  The internal variable `"v:OldObject"` is used to match any existing object
  before deletion. Avoid using `"v:OldObject"` as a variable in surrounding
  queries to prevent unintended unification.

  ## Examples

      iex> q = TerminusDB.WOQL.update_triple("v:S", "name", "Alice")
      iex> q.op
      :and

  """
  @spec update_triple(woql_node(), woql_node(), value()) :: t()
  def update_triple(s, p, o) do
    and_([opt(delete_triple(s, p, "v:OldObject")), add_triple(s, p, o)])
  end

  @doc """
  Composes an update: optionally delete any existing quad, then add the new
  one.

  The internal variable `"v:OldObject"` is used to match any existing object
  before deletion. Avoid using `"v:OldObject"` as a variable in surrounding
  queries to prevent unintended unification.

  ## Examples

      iex> q = TerminusDB.WOQL.update_quad("v:S", "name", "Alice", "instance")
      iex> q.op
      :and

  """
  @spec update_quad(woql_node(), woql_node(), value(), String.t()) :: t()
  def update_quad(s, p, o, graph) do
    and_([opt(delete_quad(s, p, "v:OldObject", graph)), add_quad(s, p, o, graph)])
  end

  # --------------------------------------------------------------------------
  # Comparison
  # --------------------------------------------------------------------------

  @doc """
  Builds a `Less` comparison: `left < right`.

  ## Examples

      iex> q = TerminusDB.WOQL.less("v:Age", 30)
      iex> q.op
      :less

  """
  @spec less(value(), value()) :: t()
  def less(left, right) do
    %__MODULE__{op: :less, args: [left, right]}
  end

  @doc """
  Builds a `Greater` comparison: `left > right`.

  ## Examples

      iex> q = TerminusDB.WOQL.greater("v:Age", 30)
      iex> q.op
      :greater

  """
  @spec greater(value(), value()) :: t()
  def greater(left, right) do
    %__MODULE__{op: :greater, args: [left, right]}
  end

  @doc """
  Builds a `Gte` comparison: `left >= right`.

  ## Examples

      iex> q = TerminusDB.WOQL.gte("v:Age", 30)
      iex> q.op
      :gte

  """
  @spec gte(value(), value()) :: t()
  def gte(left, right) do
    %__MODULE__{op: :gte, args: [left, right]}
  end

  @doc """
  Builds an `Lte` comparison: `left <= right`.

  ## Examples

      iex> q = TerminusDB.WOQL.lte("v:Age", 30)
      iex> q.op
      :lte

  """
  @spec lte(value(), value()) :: t()
  def lte(left, right) do
    %__MODULE__{op: :lte, args: [left, right]}
  end

  @doc """
  Builds a `Like` — string similarity with edit-distance `dist`.

  ## Examples

      iex> q = TerminusDB.WOQL.like("v:Name", "Alice", 2)
      iex> q.op
      :like

  """
  @spec like(value(), value(), value()) :: t()
  def like(left, right, dist) do
    %__MODULE__{op: :like, args: [left, right, dist]}
  end

  # --------------------------------------------------------------------------
  # Schema ops
  # --------------------------------------------------------------------------

  @doc """
  Builds an `IsA` — true if `element` is a member of `of_type`.

  ## Examples

      iex> q = TerminusDB.WOQL.isa("v:X", WOQL.iri("@schema:Person"))
      iex> q.op
      :isa

  """
  @spec isa(woql_node(), woql_node()) :: t()
  def isa(element, of_type) do
    %__MODULE__{op: :isa, args: [element, of_type]}
  end

  @doc """
  Builds a `Subsumption` — true if `child` is a subclass of `parent`.

  ## Examples

      iex> q = TerminusDB.WOQL.sub(WOQL.iri("@schema:Animal"), WOQL.iri("@schema:Dog"))
      iex> q.op
      :sub

  """
  @spec sub(woql_node(), woql_node()) :: t()
  def sub(parent, child) do
    %__MODULE__{op: :sub, args: [parent, child]}
  end

  @doc """
  Alias for `sub/2`.
  """
  @spec subsumption(woql_node(), woql_node()) :: t()
  def subsumption(parent, child), do: sub(parent, child)

  @doc """
  Builds a `Typecast` — casts `value` to `type`, binding to `result`.

  ## Examples

      iex> q = TerminusDB.WOQL.cast("v:Val", "xsd:integer", "v:Result")
      iex> q.op
      :cast

  """
  @spec cast(value(), value(), value()) :: t()
  def cast(value, type, result) do
    %__MODULE__{op: :cast, args: [value, type, result]}
  end

  @doc """
  Alias for `cast/3`.
  """
  @spec typecast(value(), value(), value()) :: t()
  def typecast(value, type, result), do: cast(value, type, result)

  # --------------------------------------------------------------------------
  # Arithmetic
  # --------------------------------------------------------------------------

  @doc """
  Builds an `Eval` — evaluates an arithmetic expression and binds to `result`.

  The `expression` is typically a nested arithmetic query such as `plus/1`,
  `minus/1`, `times/1`, etc.

  ## Examples

      iex> q = TerminusDB.WOQL.eval(TerminusDB.WOQL.plus(["v:X", 5]), "v:Result")
      iex> q.op
      :eval

  """
  @spec eval(t(), value()) :: t()
  def eval(expression, result) when is_struct(expression, __MODULE__) do
    %__MODULE__{op: :eval, args: [expression, result]}
  end

  @doc """
  Builds a `Plus` — sums a list of arithmetic values.

  ## Examples

      iex> q = TerminusDB.WOQL.plus(["v:X", 5, "v:Y"])
      iex> q.op
      :plus

  """
  @spec plus([value() | t()]) :: t()
  def plus(args) when is_list(args) do
    %__MODULE__{op: :plus, args: args}
  end

  @doc """
  Builds a `Minus` — subtracts a list of arithmetic values left-to-right.

  ## Examples

      iex> q = TerminusDB.WOQL.minus(["v:X", 5])
      iex> q.op
      :minus

  """
  @spec minus([value() | t()]) :: t()
  def minus(args) when is_list(args) do
    %__MODULE__{op: :minus, args: args}
  end

  @doc """
  Builds a `Times` — multiplies a list of arithmetic values.

  ## Examples

      iex> q = TerminusDB.WOQL.times(["v:X", 5])
      iex> q.op
      :times

  """
  @spec times([value() | t()]) :: t()
  def times(args) when is_list(args) do
    %__MODULE__{op: :times, args: args}
  end

  @doc """
  Builds a `Divide` — divides a list of arithmetic values left-to-right.

  ## Examples

      iex> q = TerminusDB.WOQL.divide(["v:X", 5])
      iex> q.op
      :divide

  """
  @spec divide([value() | t()]) :: t()
  def divide(args) when is_list(args) do
    %__MODULE__{op: :divide, args: args}
  end

  @doc """
  Builds a `Div` — integer division of a list of arithmetic values.

  ## Examples

      iex> q = TerminusDB.WOQL.div(["v:X", 5])
      iex> q.op
      :div

  """
  @spec div([value() | t()]) :: t()
  def div(args) when is_list(args) do
    %__MODULE__{op: :div, args: args}
  end

  @doc """
  Builds an `Exp` — `base` raised to the power of `exponent`.

  ## Examples

      iex> q = TerminusDB.WOQL.exp("v:X", 2)
      iex> q.op
      :exp

  """
  @spec exp(value() | t(), value() | t()) :: t()
  def exp(base, exponent) do
    %__MODULE__{op: :exp, args: [base, exponent]}
  end

  @doc """
  Builds a `Floor` — greatest integer ≤ `value`.

  ## Examples

      iex> q = TerminusDB.WOQL.floor("v:X")
      iex> q.op
      :floor

  """
  @spec floor(value() | t()) :: t()
  def floor(value) do
    %__MODULE__{op: :floor, args: [value]}
  end

  @doc """
  Builds a `Sum` — sums a list of numbers into a single value.

  ## Examples

      iex> q = TerminusDB.WOQL.sum("v:List", "v:Result")
      iex> q.op
      :sum

  """
  @spec sum(value(), value()) :: t()
  def sum(list, result) do
    %__MODULE__{op: :sum, args: [list, result]}
  end

  # --------------------------------------------------------------------------
  # String ops
  # --------------------------------------------------------------------------

  @doc """
  Builds a `Concatenate` — concatenates a list of strings/vars into `result`.

  ## Examples

      iex> q = TerminusDB.WOQL.concat(["v:First", " ", "v:Last"], "v:Full")
      iex> q.op
      :concat

  """
  @spec concat([value()], value()) :: t()
  def concat(list, result) when is_list(list) do
    %__MODULE__{op: :concat, args: [list, result]}
  end

  @doc """
  Alias for `concat/2`.
  """
  @spec concatenate([value()], value()) :: t()
  def concatenate(list, result), do: concat(list, result)

  @doc """
  Builds a `Join` — joins a list into a string with `glue`.

  ## Examples

      iex> q = TerminusDB.WOQL.join("v:List", ", ", "v:Result")
      iex> q.op
      :join

  """
  @spec join(value(), value(), value()) :: t()
  def join(list, glue, output) do
    %__MODULE__{op: :join, args: [list, glue, output]}
  end

  @doc """
  Builds a `Substring` — extracts a substring with `before`/`length`/`after`.

  ## Examples

      iex> q = TerminusDB.WOQL.substr("v:String", 5, "v:Sub", 0, 0)
      iex> q.op
      :substr

  """
  @spec substr(value(), value(), value(), value(), value()) :: t()
  def substr(string, length, substring, before \\ 0, after_ \\ 0) do
    %__MODULE__{op: :substr, args: [string, length, substring, before, after_]}
  end

  @doc """
  Alias for `substr/5`.
  """
  @spec substring(value(), value(), value(), value(), value()) :: t()
  def substring(string, length, substring, before \\ 0, after_ \\ 0),
    do: substr(string, length, substring, before, after_)

  @doc """
  Builds a `Trim` — strips leading/trailing whitespace.

  ## Examples

      iex> q = TerminusDB.WOQL.trim("v:Untrimmed", "v:Trimmed")
      iex> q.op
      :trim

  """
  @spec trim(value(), value()) :: t()
  def trim(untrimmed, trimmed) do
    %__MODULE__{op: :trim, args: [untrimmed, trimmed]}
  end

  @doc """
  Builds an `Upper` — converts to uppercase.

  ## Examples

      iex> q = TerminusDB.WOQL.upper("v:Input", "v:Result")
      iex> q.op
      :upper

  """
  @spec upper(value(), value()) :: t()
  def upper(left, right) do
    %__MODULE__{op: :upper, args: [left, right]}
  end

  @doc """
  Builds a `Lower` — converts to lowercase.

  ## Examples

      iex> q = TerminusDB.WOQL.lower("v:Input", "v:Result")
      iex> q.op
      :lower

  """
  @spec lower(value(), value()) :: t()
  def lower(left, right) do
    %__MODULE__{op: :lower, args: [left, right]}
  end

  @doc """
  Builds a `Pad` — pads string to `length` with `pad`.

  ## Examples

      iex> q = TerminusDB.WOQL.pad("v:Input", "0", 10, "v:Result")
      iex> q.op
      :pad

  """
  @spec pad(value(), value(), value(), value()) :: t()
  def pad(input, pad, length, output) do
    %__MODULE__{op: :pad, args: [input, pad, length, output]}
  end

  @doc """
  Builds a `Split` — splits a string by `glue` into a list.

  ## Examples

      iex> q = TerminusDB.WOQL.split("v:String", ",", "v:Result")
      iex> q.op
      :split

  """
  @spec split(value(), value(), value()) :: t()
  def split(input, glue, output) do
    %__MODULE__{op: :split, args: [input, glue, output]}
  end

  @doc """
  Builds a `Length` — binds the length of a list.

  ## Examples

      iex> q = TerminusDB.WOQL.length("v:List", "v:Len")
      iex> q.op
      :length

  """
  @spec length(value(), value()) :: t()
  def length(list, len) do
    %__MODULE__{op: :length, args: [list, len]}
  end

  @doc """
  Builds a `Regexp` — regex match; `result_list` captures groups.

  ## Examples

      iex> q = TerminusDB.WOQL.regexp("pattern", "v:String", "v:Result")
      iex> q.op
      :regexp

  """
  @spec regexp(value(), value(), value()) :: t()
  def regexp(pattern, string, result_list) do
    %__MODULE__{op: :regexp, args: [pattern, string, result_list]}
  end

  # --------------------------------------------------------------------------
  # List / Set / Dict ops
  # --------------------------------------------------------------------------

  @doc """
  Builds a `Dot` — accesses a dictionary field or list element.

  ## Examples

      iex> q = TerminusDB.WOQL.dot("v:Doc", "field", "v:Value")
      iex> q.op
      :dot

  """
  @spec dot(value(), value(), value()) :: t()
  def dot(document, field, value) do
    %__MODULE__{op: :dot, args: [document, field, value]}
  end

  @doc """
  Builds a `Member` — iterates members of a list.

  ## Examples

      iex> q = TerminusDB.WOQL.member("v:Item", "v:List")
      iex> q.op
      :member

  """
  @spec member(value(), value()) :: t()
  def member(item, list) do
    %__MODULE__{op: :member, args: [item, list]}
  end

  @doc """
  Builds a `Slice` — slices a list `[start, end)`.

  ## Examples

      iex> q = TerminusDB.WOQL.slice("v:List", "v:Result", 0, 5)
      iex> q.op
      :slice

  """
  @spec slice(value(), value(), value(), value() | nil) :: t()
  def slice(input, result, start, end_val \\ nil) do
    %__MODULE__{op: :slice, args: [input, result, start, end_val]}
  end

  @doc """
  Builds a `SetDifference`.

  ## Examples

      iex> q = TerminusDB.WOQL.set_difference("v:A", "v:B", "v:Result")
      iex> q.op
      :set_difference

  """
  @spec set_difference(value(), value(), value()) :: t()
  def set_difference(list_a, list_b, result) do
    %__MODULE__{op: :set_difference, args: [list_a, list_b, result]}
  end

  @doc """
  Builds a `SetIntersection`.

  ## Examples

      iex> q = TerminusDB.WOQL.set_intersection("v:A", "v:B", "v:Result")
      iex> q.op
      :set_intersection

  """
  @spec set_intersection(value(), value(), value()) :: t()
  def set_intersection(list_a, list_b, result) do
    %__MODULE__{op: :set_intersection, args: [list_a, list_b, result]}
  end

  @doc """
  Builds a `SetUnion`.

  ## Examples

      iex> q = TerminusDB.WOQL.set_union("v:A", "v:B", "v:Result")
      iex> q.op
      :set_union

  """
  @spec set_union(value(), value(), value()) :: t()
  def set_union(list_a, list_b, result) do
    %__MODULE__{op: :set_union, args: [list_a, list_b, result]}
  end

  @doc """
  Builds a `SetMember` — membership test in a set.

  ## Examples

      iex> q = TerminusDB.WOQL.set_member("v:Item", "v:Set")
      iex> q.op
      :set_member

  """
  @spec set_member(value(), value()) :: t()
  def set_member(element, set) do
    %__MODULE__{op: :set_member, args: [element, set]}
  end

  @doc """
  Builds a `ListToSet` — converts a list to a set.

  ## Examples

      iex> q = TerminusDB.WOQL.list_to_set("v:List", "v:Set")
      iex> q.op
      :list_to_set

  """
  @spec list_to_set(value(), value()) :: t()
  def list_to_set(input, result) do
    %__MODULE__{op: :list_to_set, args: [input, result]}
  end

  # --------------------------------------------------------------------------
  # Path / navigation
  # --------------------------------------------------------------------------

  @doc """
  Builds a `Path` query — traverses the graph from `subject` to `object`
  following the given `pattern`.

  The pattern can be either a string (compiled via `TerminusDB.WOQL.Path`) or
  an AST node built via the structured builders (`path_star/1`, `path_plus/1`,
  etc.).

  ## String patterns

      # Simple predicate
      TerminusDB.WOQL.path("v:S", "friend", "v:O")

      # Inverse traversal
      TerminusDB.WOQL.path("v:S", "<friend", "v:O")

      # Star (zero or more)
      TerminusDB.WOQL.path("v:S", "friend*", "v:O")

      # Plus (one or more)
      TerminusDB.WOQL.path("v:S", "friend+", "v:O")

      # Bounded repetition
      TerminusDB.WOQL.path("v:S", "friend{1,3}", "v:O")

      # Alternation
      TerminusDB.WOQL.path("v:S", "friend|foe", "v:O")

      # Sequence
      TerminusDB.WOQL.path("v:S", "friend,location", "v:O")

      # Any predicate
      TerminusDB.WOQL.path("v:S", ".", "v:O")

      # Grouping
      TerminusDB.WOQL.path("v:S", "(friend|foe)*", "v:O")

  ## Structured patterns

      TerminusDB.WOQL.path("v:S",
        TerminusDB.WOQL.Path.path_star(TerminusDB.WOQL.Path.path_pred("friend")),
        "v:O"
      )

  ## Options

  - A 4th argument binds the path itself to a variable.

  ## Examples

      iex> q = TerminusDB.WOQL.path("v:S", "friend*", "v:O")
      iex> q.op
      :path

      iex> q2 = TerminusDB.WOQL.path("v:S", "friend*", "v:O", "v:Path")
      iex> q2.args
      ["v:S", {:star, {:pred, "friend"}}, "v:O", "v:Path"]

  """
  @spec path(woql_node(), String.t() | tuple(), value()) :: t()
  def path(subject, pattern, object) do
    %__MODULE__{op: :path, args: [subject, Path.normalize(pattern), object]}
  end

  @spec path(woql_node(), String.t() | tuple(), value(), woql_var()) :: t()
  def path(subject, pattern, object, path_var) do
    %__MODULE__{op: :path, args: [subject, Path.normalize(pattern), object, path_var]}
  end

  # --------------------------------------------------------------------------
  # ID generation
  # --------------------------------------------------------------------------

  @doc """
  Builds a `HashKey` — deterministic hash ID from a key list.

  ## Examples

      iex> q = TerminusDB.WOQL.unique("Person/", ["v:Name", "v:Email"], "v:ID")
      iex> q.op
      :unique

  """
  @spec unique(String.t(), [value()], woql_var()) :: t()
  def unique(prefix, key_list, uri) do
    %__MODULE__{op: :unique, args: [prefix, key_list, uri]}
  end

  @doc """
  Builds a `LexicalKey` — lexical (deterministic, non-hash) ID.

  ## Examples

      iex> q = TerminusDB.WOQL.idgen("Person/", ["v:Name"], "v:ID")
      iex> q.op
      :idgen

  """
  @spec idgen(String.t(), [value()], woql_var()) :: t()
  def idgen(prefix, key_list, uri) do
    %__MODULE__{op: :idgen, args: [prefix, key_list, uri]}
  end

  @doc """
  Alias for `idgen/3`.
  """
  @spec idgenerator(String.t(), [value()], woql_var()) :: t()
  def idgenerator(prefix, key_list, uri), do: idgen(prefix, key_list, uri)

  @doc """
  Builds a `RandomKey` — cryptographically-secure random ID.

  ## Examples

      iex> q = TerminusDB.WOQL.idgen_random("Person/", "v:ID")
      iex> q.op
      :idgen_random

  """
  @spec idgen_random(String.t(), woql_var()) :: t()
  def idgen_random(prefix, uri) do
    %__MODULE__{op: :idgen_random, args: [prefix, uri]}
  end

  @doc """
  Alias for `idgen_random/2`.
  """
  @spec random_idgen(String.t(), woql_var()) :: t()
  def random_idgen(prefix, uri), do: idgen_random(prefix, uri)

  # --------------------------------------------------------------------------
  # Document mutations
  # --------------------------------------------------------------------------

  @doc """
  Builds an `InsertDocument` — inserts a document.

  `identifier` is a variable (e.g. `"v:Id"`) that will be bound to the
  inserted document's IRI. TerminusDB 12 requires it for well-formed
  `InsertDocument` JSON-LD.

  ## Examples

      iex> q = TerminusDB.WOQL.insert_document("v:Doc")
      iex> q.op
      :insert_document

      iex> q = TerminusDB.WOQL.insert_document(%{"@type" => "Person"}, "v:Id")
      iex> q.op
      :insert_document

  """
  @spec insert_document(value(), woql_node() | nil) :: t()
  def insert_document(doc, identifier \\ nil) do
    %__MODULE__{op: :insert_document, args: [doc, identifier]}
  end

  @doc """
  Builds an `UpdateDocument` — insert-or-replace a document.

  `identifier` is a variable (e.g. `"v:Id"`) that will be bound to the
  updated document's IRI.

  ## Examples

      iex> q = TerminusDB.WOQL.update_document("v:Doc")
      iex> q.op
      :update_document

      iex> q = TerminusDB.WOQL.update_document(%{"@type" => "Person"}, "v:Id")
      iex> q.op
      :update_document

  """
  @spec update_document(value(), woql_node() | nil) :: t()
  def update_document(doc, identifier \\ nil) do
    %__MODULE__{op: :update_document, args: [doc, identifier]}
  end

  @doc """
  Builds a `DeleteDocument` — delete a document by IRI.

  ## Examples

      iex> q = TerminusDB.WOQL.delete_document("Person/Alice")
      iex> q.op
      :delete_document

  """
  @spec delete_document(woql_node()) :: t()
  def delete_document(iri) do
    %__MODULE__{op: :delete_document, args: [iri]}
  end

  # --------------------------------------------------------------------------
  # Graph context
  # --------------------------------------------------------------------------

  @doc """
  Builds a `Using` — scopes the enclosed query to a data product / collection.

  ## Examples

      iex> q = TerminusDB.WOQL.using("mydb", TerminusDB.WOQL.triple("v:S", "p", "v:O"))
      iex> q.op
      :using

  """
  @spec using(String.t(), t()) :: t()
  def using(collection, query) when is_struct(query, __MODULE__) do
    %__MODULE__{op: :using, args: [collection, query]}
  end

  @doc """
  Builds a `From` — sets the default graph for the enclosed query.

  ## Examples

      iex> q = TerminusDB.WOQL.from("instance", TerminusDB.WOQL.triple("v:S", "p", "v:O"))
      iex> q.op
      :from

  """
  @spec from(String.t(), t()) :: t()
  def from(graph, query) when is_struct(query, __MODULE__) do
    %__MODULE__{op: :from, args: [graph, query]}
  end

  @doc """
  Builds an `Into` — sets the output graph for writing.

  ## Examples

      iex> q = TerminusDB.WOQL.into("schema", TerminusDB.WOQL.add_triple("v:S", "p", "v:O"))
      iex> q.op
      :into

  """
  @spec into(String.t(), t()) :: t()
  def into(graph, query) when is_struct(query, __MODULE__) do
    %__MODULE__{op: :into, args: [graph, query]}
  end

  @doc """
  Builds a `Comment` — attaches a text comment to a sub-query.

  ## Examples

      iex> q = TerminusDB.WOQL.comment("find friends", TerminusDB.WOQL.triple("v:S", "p", "v:O"))
      iex> q.op
      :comment

  """
  @spec comment(String.t(), t()) :: t()
  def comment(text, query) when is_struct(query, __MODULE__) do
    %__MODULE__{op: :comment, args: [text, query]}
  end

  # --------------------------------------------------------------------------
  # Graph meta
  # --------------------------------------------------------------------------

  @doc """
  Builds a `Size` — binds the size (bytes) of a graph.

  ## Examples

      iex> q = TerminusDB.WOQL.size("instance", "v:Size")
      iex> q.op
      :size

  """
  @spec size(String.t(), value()) :: t()
  def size(graph, size_var) do
    %__MODULE__{op: :size, args: [graph, size_var]}
  end

  @doc """
  Builds a `TripleCount` — binds the number of triples in a graph.

  ## Examples

      iex> q = TerminusDB.WOQL.triple_count("instance", "v:Count")
      iex> q.op
      :triple_count

  """
  @spec triple_count(String.t(), value()) :: t()
  def triple_count(graph, count_var) do
    %__MODULE__{op: :triple_count, args: [graph, count_var]}
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
    Encoder.encode(query)
  end

  @doc """
  Deserializes a JSON-LD WOQL query back into a `WOQL.Query` struct.

  ## Examples

      iex> jsonld = %{"@type" => "Triple", "subject" => %{"@type" => "NodeValue", "variable" => "S"}, "predicate" => %{"@type" => "NodeValue", "node" => "name"}, "object" => %{"@type" => "Value", "variable" => "N"}}
      iex> q = TerminusDB.WOQL.from_jsonld(jsonld)
      iex> q.op
      :triple

  """
  @spec from_jsonld(map()) :: t()
  def from_jsonld(%{} = jsonld) do
    Decoder.decode(jsonld)
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

    case config.database do
      nil ->
        {:error, %Error{reason: :config, message: "no database scoped in config"}}

      db ->
        repo = opts[:repo] || config.repo
        branch = opts[:branch] || config.branch
        path = "woql/#{org}/#{db}/#{repo}/branch/#{branch}"

        body =
          %{"query" => to_jsonld(query)}
          |> Params.maybe_put("commit_info", build_commit_info(opts))
          |> Params.maybe_put("all_witnesses", opts[:all_witnesses])

        Client.request(config, :post, path, json: body, area: :woql)
    end
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

  defp build_commit_info(opts) do
    author = opts[:author]
    message = opts[:message]

    if author || message do
      %{"author" => author || "", "message" => message || ""}
    end
  end

  defp normalize_order_specs(specs) do
    Enum.map(specs, &normalize_order_spec/1)
  end

  defp normalize_order_spec({var, order}) when is_binary(var) and is_atom(order) do
    name = if String.starts_with?(var, "v:"), do: String.slice(var, 2..-1//1), else: var
    {name, Atom.to_string(order)}
  end

  defp normalize_order_spec({key, order}) when is_atom(key) and is_atom(order) do
    {Atom.to_string(key), Atom.to_string(order)}
  end
end
