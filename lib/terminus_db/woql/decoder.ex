defmodule TerminusDB.WOQL.Decoder do
  @moduledoc false

  # JSON-LD decoder for WOQL queries — inverse of TerminusDB.WOQL.Encoder.
  # Handles all four wrapper types: NodeValue, Value, DataValue, ArithmeticValue.

  def decode(%{"@type" => "Triple", "graph" => graph} = m) do
    TerminusDB.WOQL.quad(
      decode_node(m["subject"]),
      decode_node(m["predicate"]),
      decode_value(m["object"]),
      graph
    )
  end

  def decode(%{"@type" => "Triple"} = m) do
    TerminusDB.WOQL.triple(
      decode_node(m["subject"]),
      decode_node(m["predicate"]),
      decode_value(m["object"])
    )
  end

  def decode(%{"@type" => "And", "and" => queries}) do
    TerminusDB.WOQL.and_(Enum.map(queries, &decode/1))
  end

  def decode(%{"@type" => "Or", "or" => queries}) do
    TerminusDB.WOQL.or_(Enum.map(queries, &decode/1))
  end

  def decode(%{"@type" => "Equals"} = m) do
    TerminusDB.WOQL.eq(decode_value(m["left"]), decode_value(m["right"]))
  end

  def decode(%{"@type" => "Select", "variables" => vars, "query" => query}) do
    TerminusDB.WOQL.select(Enum.map(vars, &decode_select_var/1), decode(query))
  end

  def decode(%{"@type" => "ReadDocument"} = m) do
    TerminusDB.WOQL.read_document(decode_node(m["identifier"]), decode_value(m["document"]))
  end

  def decode(%{"@type" => "TypeOf"} = m) do
    TerminusDB.WOQL.type_of(decode_value(m["value"]), decode_value(m["type"]))
  end

  def decode(%{"@type" => "True"}) do
    TerminusDB.WOQL.true_()
  end

  def decode(%{"@type" => "Not", "query" => q}) do
    TerminusDB.WOQL.not_(decode(q))
  end

  def decode(%{"@type" => "Optional", "query" => q}) do
    TerminusDB.WOQL.opt(decode(q))
  end

  def decode(%{"@type" => "Once", "query" => q}) do
    TerminusDB.WOQL.once(decode(q))
  end

  def decode(%{"@type" => "Immediately", "query" => q}) do
    TerminusDB.WOQL.immediately(decode(q))
  end

  def decode(%{"@type" => "Distinct", "variables" => vars, "query" => q}) do
    TerminusDB.WOQL.distinct(Enum.map(vars, &decode_select_var/1), decode(q))
  end

  def decode(%{"@type" => "Limit", "limit" => n, "query" => q}) do
    TerminusDB.WOQL.limit(n, decode(q))
  end

  def decode(%{"@type" => "Start", "start" => n, "query" => q}) do
    TerminusDB.WOQL.start(n, decode(q))
  end

  def decode(%{"@type" => "OrderBy", "ordering" => ordering, "query" => q}) do
    specs =
      Enum.map(ordering, fn %{"variable" => var, "order" => order} ->
        {var, decode_order(order)}
      end)

    TerminusDB.WOQL.order_by(specs, decode(q))
  end

  def decode(%{
        "@type" => "GroupBy",
        "group_by" => vars,
        "template" => template,
        "grouped" => grouped,
        "query" => q
      }) do
    TerminusDB.WOQL.group_by(
      Enum.map(vars, &decode_select_var/1),
      decode_value(template),
      decode_value(grouped),
      decode(q)
    )
  end

  def decode(%{"@type" => "Count", "count" => countvar, "query" => q}) do
    TerminusDB.WOQL.count(decode_value(countvar), decode(q))
  end

  def decode(%{"@type" => "Collect", "template" => template, "into" => into, "query" => q}) do
    TerminusDB.WOQL.collect(decode_value(template), decode_value(into), decode(q))
  end

  def decode(%{"@type" => "AddedTriple", "graph" => graph} = m) do
    TerminusDB.WOQL.added_quad(
      decode_node(m["subject"]),
      decode_node(m["predicate"]),
      decode_value(m["object"]),
      graph
    )
  end

  def decode(%{"@type" => "AddedTriple"} = m) do
    TerminusDB.WOQL.added_triple(
      decode_node(m["subject"]),
      decode_node(m["predicate"]),
      decode_value(m["object"])
    )
  end

  def decode(%{"@type" => "DeletedTriple", "graph" => graph} = m) do
    TerminusDB.WOQL.removed_quad(
      decode_node(m["subject"]),
      decode_node(m["predicate"]),
      decode_value(m["object"]),
      graph
    )
  end

  def decode(%{"@type" => "DeletedTriple"} = m) do
    TerminusDB.WOQL.removed_triple(
      decode_node(m["subject"]),
      decode_node(m["predicate"]),
      decode_value(m["object"])
    )
  end

  def decode(%{"@type" => "AddTriple", "graph" => graph} = m) do
    TerminusDB.WOQL.add_quad(
      decode_node(m["subject"]),
      decode_node(m["predicate"]),
      decode_value(m["object"]),
      graph
    )
  end

  def decode(%{"@type" => "AddTriple"} = m) do
    TerminusDB.WOQL.add_triple(
      decode_node(m["subject"]),
      decode_node(m["predicate"]),
      decode_value(m["object"])
    )
  end

  def decode(%{"@type" => "DeleteTriple", "graph" => graph} = m) do
    TerminusDB.WOQL.delete_quad(
      decode_node(m["subject"]),
      decode_node(m["predicate"]),
      decode_value(m["object"]),
      graph
    )
  end

  def decode(%{"@type" => "DeleteTriple"} = m) do
    TerminusDB.WOQL.delete_triple(
      decode_node(m["subject"]),
      decode_node(m["predicate"]),
      decode_value(m["object"])
    )
  end

  def decode(%{"@type" => "Less"} = m) do
    TerminusDB.WOQL.less(decode_value(m["left"]), decode_value(m["right"]))
  end

  def decode(%{"@type" => "Greater"} = m) do
    TerminusDB.WOQL.greater(decode_value(m["left"]), decode_value(m["right"]))
  end

  def decode(%{"@type" => "Gte"} = m) do
    TerminusDB.WOQL.gte(decode_value(m["left"]), decode_value(m["right"]))
  end

  def decode(%{"@type" => "Lte"} = m) do
    TerminusDB.WOQL.lte(decode_value(m["left"]), decode_value(m["right"]))
  end

  def decode(%{"@type" => "Like"} = m) do
    TerminusDB.WOQL.like(
      decode_value(m["left"]),
      decode_value(m["right"]),
      decode_value(m["distance"])
    )
  end

  def decode(%{"@type" => "IsA"} = m) do
    TerminusDB.WOQL.isa(decode_node(m["element"]), decode_node(m["type"]))
  end

  def decode(%{"@type" => "Subsumption"} = m) do
    TerminusDB.WOQL.sub(decode_node(m["parent"]), decode_node(m["child"]))
  end

  def decode(%{"@type" => "Typecast"} = m) do
    TerminusDB.WOQL.cast(
      decode_value(m["value"]),
      decode_value(m["type"]),
      decode_value(m["result"])
    )
  end

  def decode(%{"@type" => "Eval", "expression" => expr, "result" => result}) do
    TerminusDB.WOQL.eval(decode_arithmetic(expr), decode_value(result))
  end

  def decode(%{"@type" => "Plus", "arguments" => args}) do
    TerminusDB.WOQL.plus(Enum.map(args, &decode_arithmetic/1))
  end

  def decode(%{"@type" => "Minus", "arguments" => args}) do
    TerminusDB.WOQL.minus(Enum.map(args, &decode_arithmetic/1))
  end

  def decode(%{"@type" => "Times", "arguments" => args}) do
    TerminusDB.WOQL.times(Enum.map(args, &decode_arithmetic/1))
  end

  def decode(%{"@type" => "Divide", "arguments" => args}) do
    TerminusDB.WOQL.divide(Enum.map(args, &decode_arithmetic/1))
  end

  def decode(%{"@type" => "Div", "arguments" => args}) do
    TerminusDB.WOQL.div(Enum.map(args, &decode_arithmetic/1))
  end

  def decode(%{"@type" => "Exp", "first" => base, "second" => exponent}) do
    TerminusDB.WOQL.exp(decode_arithmetic(base), decode_arithmetic(exponent))
  end

  def decode(%{"@type" => "Floor", "data" => value}) do
    TerminusDB.WOQL.floor(decode_arithmetic(value))
  end

  def decode(%{"@type" => "Sum", "list" => list, "result" => result}) do
    TerminusDB.WOQL.sum(decode_value(list), decode_value(result))
  end

  def decode(%{"@type" => "Concatenate", "list" => list, "result" => result}) do
    TerminusDB.WOQL.concat(Enum.map(list, &decode_data/1), decode_data(result))
  end

  def decode(%{"@type" => "Join", "list" => list, "glue" => glue, "result" => output}) do
    TerminusDB.WOQL.join(decode_data(list), decode_data(glue), decode_data(output))
  end

  def decode(%{"@type" => "Substring"} = m) do
    TerminusDB.WOQL.substr(
      decode_data(m["string"]),
      decode_data(m["length"]),
      decode_data(m["substring"]),
      decode_data(m["before"]),
      decode_data(m["after"])
    )
  end

  def decode(%{"@type" => "Trim", "untrimmed" => u, "trimmed" => t}) do
    TerminusDB.WOQL.trim(decode_data(u), decode_data(t))
  end

  def decode(%{"@type" => "Upper", "left" => l, "right" => r}) do
    TerminusDB.WOQL.upper(decode_data(l), decode_data(r))
  end

  def decode(%{"@type" => "Lower", "left" => l, "right" => r}) do
    TerminusDB.WOQL.lower(decode_data(l), decode_data(r))
  end

  def decode(%{"@type" => "Pad"} = m) do
    TerminusDB.WOQL.pad(
      decode_data(m["string"]),
      decode_data(m["pad"]),
      decode_data(m["length"]),
      decode_data(m["result"])
    )
  end

  def decode(%{"@type" => "Split", "string" => s, "glue" => g, "result" => r}) do
    TerminusDB.WOQL.split(decode_data(s), decode_data(g), decode_data(r))
  end

  def decode(%{"@type" => "Length", "list" => list, "length" => len}) do
    TerminusDB.WOQL.length(decode_value(list), decode_value(len))
  end

  def decode(%{"@type" => "Regexp", "pattern" => p, "string" => s, "result" => r}) do
    TerminusDB.WOQL.regexp(decode_data(p), decode_data(s), decode_data(r))
  end

  def decode(%{"@type" => "Dot", "document" => d, "field" => f, "value" => v}) do
    TerminusDB.WOQL.dot(decode_value(d), decode_data(f), decode_value(v))
  end

  def decode(%{"@type" => "Member", "member" => m, "list" => l}) do
    TerminusDB.WOQL.member(decode_value(m), decode_value(l))
  end

  def decode(%{"@type" => "Slice"} = m) do
    TerminusDB.WOQL.slice(
      decode_value(m["list"]),
      decode_value(m["slice"]),
      decode_value(m["from"]),
      decode_value(m["to"])
    )
  end

  def decode(%{"@type" => "SetDifference", "left" => l, "right" => r, "result" => res}) do
    TerminusDB.WOQL.set_difference(decode_value(l), decode_value(r), decode_value(res))
  end

  def decode(%{"@type" => "SetIntersection", "left" => l, "right" => r, "result" => res}) do
    TerminusDB.WOQL.set_intersection(decode_value(l), decode_value(r), decode_value(res))
  end

  def decode(%{"@type" => "SetUnion", "left" => l, "right" => r, "result" => res}) do
    TerminusDB.WOQL.set_union(decode_value(l), decode_value(r), decode_value(res))
  end

  def decode(%{"@type" => "SetMember", "element" => e, "set" => s}) do
    TerminusDB.WOQL.set_member(decode_value(e), decode_value(s))
  end

  def decode(%{"@type" => "ListToSet", "list" => l, "result" => r}) do
    TerminusDB.WOQL.list_to_set(decode_value(l), decode_value(r))
  end

  def decode(%{"@type" => "Path"} = m) do
    subject = decode_node(m["subject"])
    pattern = TerminusDB.WOQL.Path.from_jsonld(m["pattern"])
    object = decode_value(m["object"])

    if m["path"] do
      TerminusDB.WOQL.path(subject, pattern, object, decode_value(m["path"]))
    else
      TerminusDB.WOQL.path(subject, pattern, object)
    end
  end

  def decode(%{"@type" => "HashKey", "base" => base, "key_list" => key_list, "uri" => uri}) do
    TerminusDB.WOQL.unique(
      decode_data(base),
      Enum.map(key_list, &decode_data/1),
      decode_node(uri)
    )
  end

  def decode(%{"@type" => "LexicalKey", "base" => base, "key_list" => key_list, "uri" => uri}) do
    TerminusDB.WOQL.idgen(
      decode_data(base),
      Enum.map(key_list, &decode_data/1),
      decode_node(uri)
    )
  end

  def decode(%{"@type" => "RandomKey", "base" => base, "uri" => uri}) do
    TerminusDB.WOQL.idgen_random(decode_data(base), decode_node(uri))
  end

  def decode(%{"@type" => "InsertDocument", "document" => doc}) do
    TerminusDB.WOQL.insert_document(decode_value(doc))
  end

  def decode(%{"@type" => "UpdateDocument", "document" => doc}) do
    TerminusDB.WOQL.update_document(decode_value(doc))
  end

  def decode(%{"@type" => "DeleteDocument", "identifier" => iri}) do
    TerminusDB.WOQL.delete_document(decode_node(iri))
  end

  def decode(%{"@type" => "Using", "collection" => collection, "query" => q}) do
    TerminusDB.WOQL.using(collection, decode(q))
  end

  def decode(%{"@type" => "From", "graph" => graph, "query" => q}) do
    TerminusDB.WOQL.from(graph, decode(q))
  end

  def decode(%{"@type" => "Into", "graph" => graph, "query" => q}) do
    TerminusDB.WOQL.into(graph, decode(q))
  end

  def decode(%{"@type" => "Comment", "comment" => %{"@value" => text}, "query" => q}) do
    TerminusDB.WOQL.comment(text, decode(q))
  end

  def decode(%{"@type" => "Size", "graph" => graph, "size" => size_var}) do
    TerminusDB.WOQL.size(graph, decode_value(size_var))
  end

  def decode(%{"@type" => "TripleCount", "graph" => graph, "triple_count" => count_var}) do
    TerminusDB.WOQL.triple_count(graph, decode_value(count_var))
  end

  # --------------------------------------------------------------------------
  # NodeValue decoder
  # --------------------------------------------------------------------------

  def decode_node(%{"@type" => "NodeValue", "variable" => name}) do
    "v:#{name}"
  end

  def decode_node(%{"@type" => "NodeValue", "node" => node}) do
    node
  end

  def decode_node(value), do: value

  # --------------------------------------------------------------------------
  # Value decoder (also accepts DataValue/NodeValue for backward compat)
  # --------------------------------------------------------------------------

  def decode_value(%{"@type" => "Value", "variable" => name}) do
    "v:#{name}"
  end

  def decode_value(%{"@type" => "Value", "node" => node}) do
    node
  end

  def decode_value(%{"@type" => "Value", "data" => %{"@value" => value}}) do
    value
  end

  def decode_value(%{"@type" => "DataValue", "variable" => name}) do
    "v:#{name}"
  end

  def decode_value(%{"@type" => "DataValue", "data" => %{"@value" => value}}) do
    value
  end

  def decode_value(%{"@type" => "NodeValue", "variable" => name}) do
    "v:#{name}"
  end

  def decode_value(%{"@type" => "NodeValue", "node" => node}) do
    node
  end

  def decode_value(value), do: value

  # --------------------------------------------------------------------------
  # DataValue decoder
  # --------------------------------------------------------------------------

  def decode_data(%{"@type" => "DataValue", "variable" => name}) do
    "v:#{name}"
  end

  def decode_data(%{"@type" => "DataValue", "data" => %{"@value" => value}}) do
    value
  end

  def decode_data(%{"@type" => "Value", "variable" => name}) do
    "v:#{name}"
  end

  def decode_data(%{"@type" => "Value", "data" => %{"@value" => value}}) do
    value
  end

  def decode_data(value), do: value

  # --------------------------------------------------------------------------
  # ArithmeticValue decoder
  # --------------------------------------------------------------------------

  def decode_arithmetic(%{"@type" => "ArithmeticValue", "variable" => name}) do
    "v:#{name}"
  end

  def decode_arithmetic(%{"@type" => "ArithmeticValue", "data" => %{"@value" => value}}) do
    value
  end

  def decode_arithmetic(%{"@type" => type} = value) when type != "ArithmeticValue" do
    decode(value)
  end

  def decode_arithmetic(value), do: value

  # --------------------------------------------------------------------------
  # Select variables
  # --------------------------------------------------------------------------

  def decode_select_var(name) when is_binary(name), do: "v:#{name}"

  defp decode_order("asc"), do: :asc
  defp decode_order("desc"), do: :desc
  defp decode_order(other), do: other
end
