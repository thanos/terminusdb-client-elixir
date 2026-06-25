defmodule TerminusDB.WOQL.Encoder do
  @moduledoc false

  # JSON-LD encoder for WOQL queries.
  #
  # Uses four value-wrapper types matching the Python/JS clients:
  #
  #   NodeValue      — nodes/IRIs (subjects, predicates, identifiers)
  #   Value          — generic values (triple objects, comparison operands)
  #   DataValue      — literal data (string-op operands, ID-gen keys)
  #   ArithmeticValue — arithmetic operands
  #
  # Variables use the "v:Name" convention. Each wrapper has variable/node/data
  # fields as appropriate:
  #
  #   {"@type": "<Wrapper>", "variable": "Name"}          — variable
  #   {"@type": "NodeValue", "node": "iri"}               — IRI constant
  #   {"@type": "<Wrapper>", "data": {"@type": "xsd:…", "@value": …}} — literal

  def encode(%TerminusDB.WOQL{op: :triple, args: [s, p, o]}) do
    %{
      "@type" => "Triple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o)
    }
  end

  def encode(%TerminusDB.WOQL{op: :and, args: queries}) do
    %{
      "@type" => "And",
      "and" => Enum.map(queries, &encode/1)
    }
  end

  def encode(%TerminusDB.WOQL{op: :or, args: queries}) do
    %{
      "@type" => "Or",
      "or" => Enum.map(queries, &encode/1)
    }
  end

  def encode(%TerminusDB.WOQL{op: :eq, args: [left, right]}) do
    %{
      "@type" => "Equals",
      "left" => encode_value(left),
      "right" => encode_value(right)
    }
  end

  def encode(%TerminusDB.WOQL{op: :select, args: [vars, query]}) do
    %{
      "@type" => "Select",
      "variables" => Enum.map(vars, &encode_select_var/1),
      "query" => encode(query)
    }
  end

  def encode(%TerminusDB.WOQL{op: :read_document, args: [id, var]}) do
    %{
      "@type" => "ReadDocument",
      "identifier" => encode_node(id),
      "document" => encode_value(var)
    }
  end

  def encode(%TerminusDB.WOQL{op: :type_of, args: [node, var]}) do
    %{
      "@type" => "TypeOf",
      "value" => encode_value(node),
      "type" => encode_value(var)
    }
  end

  def encode(%TerminusDB.WOQL{op: true, args: []}) do
    %{"@type" => "True"}
  end

  def encode(%TerminusDB.WOQL{op: :not, args: [query]}) do
    %{"@type" => "Not", "query" => encode(query)}
  end

  def encode(%TerminusDB.WOQL{op: :opt, args: [query]}) do
    %{"@type" => "Optional", "query" => encode(query)}
  end

  def encode(%TerminusDB.WOQL{op: :once, args: [query]}) do
    %{"@type" => "Once", "query" => encode(query)}
  end

  def encode(%TerminusDB.WOQL{op: :immediately, args: [query]}) do
    %{"@type" => "Immediately", "query" => encode(query)}
  end

  def encode(%TerminusDB.WOQL{op: :distinct, args: [vars, query]}) do
    %{
      "@type" => "Distinct",
      "variables" => Enum.map(vars, &encode_select_var/1),
      "query" => encode(query)
    }
  end

  def encode(%TerminusDB.WOQL{op: :limit, args: [n, query]}) do
    %{"@type" => "Limit", "limit" => n, "query" => encode(query)}
  end

  def encode(%TerminusDB.WOQL{op: :start, args: [n, query]}) do
    %{"@type" => "Start", "start" => n, "query" => encode(query)}
  end

  def encode(%TerminusDB.WOQL{op: :order_by, args: [specs, query]}) do
    %{
      "@type" => "OrderBy",
      "ordering" =>
        Enum.map(specs, fn {var, order} ->
          %{"@type" => "OrderTemplate", "variable" => var, "order" => order}
        end),
      "query" => encode(query)
    }
  end

  def encode(%TerminusDB.WOQL{op: :group_by, args: [vars, template, grouped, query]}) do
    %{
      "@type" => "GroupBy",
      "group_by" => Enum.map(vars, &encode_select_var/1),
      "template" => encode_value(template),
      "grouped" => encode_value(grouped),
      "query" => encode(query)
    }
  end

  def encode(%TerminusDB.WOQL{op: :count, args: [countvar, query]}) do
    %{"@type" => "Count", "count" => encode_value(countvar), "query" => encode(query)}
  end

  def encode(%TerminusDB.WOQL{op: :collect, args: [template, into, query]}) do
    %{
      "@type" => "Collect",
      "template" => encode_value(template),
      "into" => encode_value(into),
      "query" => encode(query)
    }
  end

  def encode(%TerminusDB.WOQL{op: :quad, args: [s, p, o, graph]}) do
    %{
      "@type" => "Triple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o),
      "graph" => graph
    }
  end

  def encode(%TerminusDB.WOQL{op: :added_triple, args: [s, p, o]}) do
    %{
      "@type" => "AddedTriple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o)
    }
  end

  def encode(%TerminusDB.WOQL{op: :removed_triple, args: [s, p, o]}) do
    %{
      "@type" => "DeletedTriple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o)
    }
  end

  def encode(%TerminusDB.WOQL{op: :added_quad, args: [s, p, o, graph]}) do
    %{
      "@type" => "AddedTriple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o),
      "graph" => graph
    }
  end

  def encode(%TerminusDB.WOQL{op: :removed_quad, args: [s, p, o, graph]}) do
    %{
      "@type" => "DeletedTriple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o),
      "graph" => graph
    }
  end

  def encode(%TerminusDB.WOQL{op: :add_triple, args: [s, p, o]}) do
    %{
      "@type" => "AddTriple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o)
    }
  end

  def encode(%TerminusDB.WOQL{op: :delete_triple, args: [s, p, o]}) do
    %{
      "@type" => "DeleteTriple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o)
    }
  end

  def encode(%TerminusDB.WOQL{op: :add_quad, args: [s, p, o, graph]}) do
    %{
      "@type" => "AddTriple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o),
      "graph" => graph
    }
  end

  def encode(%TerminusDB.WOQL{op: :delete_quad, args: [s, p, o, graph]}) do
    %{
      "@type" => "DeleteTriple",
      "subject" => encode_node(s),
      "predicate" => encode_node(p),
      "object" => encode_value(o),
      "graph" => graph
    }
  end

  def encode(%TerminusDB.WOQL{op: :less, args: [left, right]}) do
    %{"@type" => "Less", "left" => encode_value(left), "right" => encode_value(right)}
  end

  def encode(%TerminusDB.WOQL{op: :greater, args: [left, right]}) do
    %{"@type" => "Greater", "left" => encode_value(left), "right" => encode_value(right)}
  end

  def encode(%TerminusDB.WOQL{op: :gte, args: [left, right]}) do
    %{"@type" => "Gte", "left" => encode_value(left), "right" => encode_value(right)}
  end

  def encode(%TerminusDB.WOQL{op: :lte, args: [left, right]}) do
    %{"@type" => "Lte", "left" => encode_value(left), "right" => encode_value(right)}
  end

  def encode(%TerminusDB.WOQL{op: :like, args: [left, right, dist]}) do
    %{
      "@type" => "Like",
      "left" => encode_value(left),
      "right" => encode_value(right),
      "distance" => encode_value(dist)
    }
  end

  def encode(%TerminusDB.WOQL{op: :isa, args: [element, type]}) do
    %{"@type" => "IsA", "element" => encode_node(element), "type" => encode_node(type)}
  end

  def encode(%TerminusDB.WOQL{op: :sub, args: [parent, child]}) do
    %{"@type" => "Subsumption", "parent" => encode_node(parent), "child" => encode_node(child)}
  end

  def encode(%TerminusDB.WOQL{op: :cast, args: [value, type, result]}) do
    %{
      "@type" => "Typecast",
      "value" => encode_value(value),
      "type" => encode_value(type),
      "result" => encode_value(result)
    }
  end

  def encode(%TerminusDB.WOQL{op: :eval, args: [expression, result]}) do
    %{
      "@type" => "Eval",
      "expression" => encode_arithmetic(expression),
      "result" => encode_value(result)
    }
  end

  def encode(%TerminusDB.WOQL{op: :plus, args: args}) do
    %{"@type" => "Plus", "arguments" => Enum.map(args, &encode_arithmetic/1)}
  end

  def encode(%TerminusDB.WOQL{op: :minus, args: args}) do
    %{"@type" => "Minus", "arguments" => Enum.map(args, &encode_arithmetic/1)}
  end

  def encode(%TerminusDB.WOQL{op: :times, args: args}) do
    %{"@type" => "Times", "arguments" => Enum.map(args, &encode_arithmetic/1)}
  end

  def encode(%TerminusDB.WOQL{op: :divide, args: args}) do
    %{"@type" => "Divide", "arguments" => Enum.map(args, &encode_arithmetic/1)}
  end

  def encode(%TerminusDB.WOQL{op: :div, args: args}) do
    %{"@type" => "Div", "arguments" => Enum.map(args, &encode_arithmetic/1)}
  end

  def encode(%TerminusDB.WOQL{op: :exp, args: [base, exponent]}) do
    %{
      "@type" => "Exp",
      "first" => encode_arithmetic(base),
      "second" => encode_arithmetic(exponent)
    }
  end

  def encode(%TerminusDB.WOQL{op: :floor, args: [value]}) do
    %{"@type" => "Floor", "data" => encode_arithmetic(value)}
  end

  def encode(%TerminusDB.WOQL{op: :sum, args: [list, result]}) do
    %{"@type" => "Sum", "list" => encode_value(list), "result" => encode_value(result)}
  end

  def encode(%TerminusDB.WOQL{op: :concat, args: [list, result]}) do
    %{
      "@type" => "Concatenate",
      "list" => Enum.map(list, &encode_data/1),
      "result" => encode_data(result)
    }
  end

  def encode(%TerminusDB.WOQL{op: :join, args: [list, glue, output]}) do
    %{
      "@type" => "Join",
      "list" => encode_data(list),
      "glue" => encode_data(glue),
      "result" => encode_data(output)
    }
  end

  def encode(%TerminusDB.WOQL{op: :substr, args: [string, length, substring, before, after_]}) do
    %{
      "@type" => "Substring",
      "string" => encode_data(string),
      "length" => encode_data(length),
      "substring" => encode_data(substring),
      "before" => encode_data(before),
      "after" => encode_data(after_)
    }
  end

  def encode(%TerminusDB.WOQL{op: :trim, args: [untrimmed, trimmed]}) do
    %{"@type" => "Trim", "untrimmed" => encode_data(untrimmed), "trimmed" => encode_data(trimmed)}
  end

  def encode(%TerminusDB.WOQL{op: :upper, args: [left, right]}) do
    %{"@type" => "Upper", "left" => encode_data(left), "right" => encode_data(right)}
  end

  def encode(%TerminusDB.WOQL{op: :lower, args: [left, right]}) do
    %{"@type" => "Lower", "left" => encode_data(left), "right" => encode_data(right)}
  end

  def encode(%TerminusDB.WOQL{op: :pad, args: [input, pad, length, output]}) do
    %{
      "@type" => "Pad",
      "string" => encode_data(input),
      "pad" => encode_data(pad),
      "length" => encode_data(length),
      "result" => encode_data(output)
    }
  end

  def encode(%TerminusDB.WOQL{op: :split, args: [input, glue, output]}) do
    %{
      "@type" => "Split",
      "string" => encode_data(input),
      "glue" => encode_data(glue),
      "result" => encode_data(output)
    }
  end

  def encode(%TerminusDB.WOQL{op: :length, args: [list, len]}) do
    %{"@type" => "Length", "list" => encode_value(list), "length" => encode_value(len)}
  end

  def encode(%TerminusDB.WOQL{op: :regexp, args: [pattern, string, result_list]}) do
    %{
      "@type" => "Regexp",
      "pattern" => encode_data(pattern),
      "string" => encode_data(string),
      "result" => encode_data(result_list)
    }
  end

  def encode(%TerminusDB.WOQL{op: :dot, args: [document, field, value]}) do
    %{
      "@type" => "Dot",
      "document" => encode_value(document),
      "field" => encode_data(field),
      "value" => encode_value(value)
    }
  end

  def encode(%TerminusDB.WOQL{op: :member, args: [item, list]}) do
    %{"@type" => "Member", "member" => encode_value(item), "list" => encode_value(list)}
  end

  def encode(%TerminusDB.WOQL{op: :slice, args: [input, result, start, end_val]}) do
    %{
      "@type" => "Slice",
      "list" => encode_value(input),
      "slice" => encode_value(result),
      "from" => encode_value(start),
      "to" => encode_value(end_val)
    }
  end

  def encode(%TerminusDB.WOQL{op: :set_difference, args: [list_a, list_b, result]}) do
    %{
      "@type" => "SetDifference",
      "left" => encode_value(list_a),
      "right" => encode_value(list_b),
      "result" => encode_value(result)
    }
  end

  def encode(%TerminusDB.WOQL{op: :set_intersection, args: [list_a, list_b, result]}) do
    %{
      "@type" => "SetIntersection",
      "left" => encode_value(list_a),
      "right" => encode_value(list_b),
      "result" => encode_value(result)
    }
  end

  def encode(%TerminusDB.WOQL{op: :set_union, args: [list_a, list_b, result]}) do
    %{
      "@type" => "SetUnion",
      "left" => encode_value(list_a),
      "right" => encode_value(list_b),
      "result" => encode_value(result)
    }
  end

  def encode(%TerminusDB.WOQL{op: :set_member, args: [element, set]}) do
    %{"@type" => "SetMember", "element" => encode_value(element), "set" => encode_value(set)}
  end

  def encode(%TerminusDB.WOQL{op: :list_to_set, args: [input, result]}) do
    %{"@type" => "ListToSet", "list" => encode_value(input), "result" => encode_value(result)}
  end

  def encode(%TerminusDB.WOQL{op: :path, args: [subject, pattern, object]}) do
    %{
      "@type" => "Path",
      "subject" => encode_node(subject),
      "pattern" => TerminusDB.WOQL.Path.to_jsonld(pattern),
      "object" => encode_value(object)
    }
  end

  def encode(%TerminusDB.WOQL{op: :path, args: [subject, pattern, object, path_var]}) do
    %{
      "@type" => "Path",
      "subject" => encode_node(subject),
      "pattern" => TerminusDB.WOQL.Path.to_jsonld(pattern),
      "object" => encode_value(object),
      "path" => encode_value(path_var)
    }
  end

  def encode(%TerminusDB.WOQL{op: :unique, args: [prefix, key_list, uri]}) do
    %{
      "@type" => "HashKey",
      "base" => encode_data(prefix),
      "key_list" => Enum.map(key_list, &encode_data/1),
      "uri" => encode_node(uri)
    }
  end

  def encode(%TerminusDB.WOQL{op: :idgen, args: [prefix, key_list, uri]}) do
    %{
      "@type" => "LexicalKey",
      "base" => encode_data(prefix),
      "key_list" => Enum.map(key_list, &encode_data/1),
      "uri" => encode_node(uri)
    }
  end

  def encode(%TerminusDB.WOQL{op: :idgen_random, args: [prefix, uri]}) do
    %{"@type" => "RandomKey", "base" => encode_data(prefix), "uri" => encode_node(uri)}
  end

  def encode(%TerminusDB.WOQL{op: :insert_document, args: [doc]}) do
    %{"@type" => "InsertDocument", "document" => encode_value(doc)}
  end

  def encode(%TerminusDB.WOQL{op: :update_document, args: [doc]}) do
    %{"@type" => "UpdateDocument", "document" => encode_value(doc)}
  end

  def encode(%TerminusDB.WOQL{op: :delete_document, args: [iri]}) do
    %{"@type" => "DeleteDocument", "identifier" => encode_node(iri)}
  end

  def encode(%TerminusDB.WOQL{op: :using, args: [collection, query]}) do
    %{"@type" => "Using", "collection" => collection, "query" => encode(query)}
  end

  def encode(%TerminusDB.WOQL{op: :from, args: [graph, query]}) do
    %{"@type" => "From", "graph" => graph, "query" => encode(query)}
  end

  def encode(%TerminusDB.WOQL{op: :into, args: [graph, query]}) do
    %{"@type" => "Into", "graph" => graph, "query" => encode(query)}
  end

  def encode(%TerminusDB.WOQL{op: :comment, args: [text, query]}) do
    %{
      "@type" => "Comment",
      "comment" => %{"@type" => "xsd:string", "@value" => text},
      "query" => encode(query)
    }
  end

  def encode(%TerminusDB.WOQL{op: :size, args: [graph, size_var]}) do
    %{"@type" => "Size", "graph" => graph, "size" => encode_value(size_var)}
  end

  def encode(%TerminusDB.WOQL{op: :triple_count, args: [graph, count_var]}) do
    %{"@type" => "TripleCount", "graph" => graph, "triple_count" => encode_value(count_var)}
  end

  # --------------------------------------------------------------------------
  # NodeValue — nodes/IRIs (subjects, predicates, identifiers)
  # --------------------------------------------------------------------------

  def encode_node(var) when is_binary(var) and binary_part(var, 0, 2) == "v:" do
    %{"@type" => "NodeValue", "variable" => String.slice(var, 2..-1//1)}
  end

  def encode_node(value) when is_binary(value) do
    %{"@type" => "NodeValue", "node" => value}
  end

  def encode_node(value) when is_map(value), do: value

  # --------------------------------------------------------------------------
  # Value — generic values (triple objects, comparison operands, type_of)
  # --------------------------------------------------------------------------

  def encode_value(var) when is_binary(var) and binary_part(var, 0, 2) == "v:" do
    %{"@type" => "Value", "variable" => String.slice(var, 2..-1//1)}
  end

  def encode_value(value) when is_binary(value) do
    %{"@type" => "Value", "data" => %{"@type" => "xsd:string", "@value" => value}}
  end

  def encode_value(value) when is_integer(value) do
    %{"@type" => "Value", "data" => %{"@type" => "xsd:integer", "@value" => value}}
  end

  def encode_value(value) when is_float(value) do
    %{"@type" => "Value", "data" => %{"@type" => "xsd:decimal", "@value" => value}}
  end

  def encode_value(value) when is_boolean(value) do
    %{"@type" => "Value", "data" => %{"@type" => "xsd:boolean", "@value" => value}}
  end

  def encode_value(%{"@value" => _} = literal) do
    %{"@type" => "Value", "data" => literal}
  end

  def encode_value(value) when is_map(value), do: value

  # --------------------------------------------------------------------------
  # DataValue — literal data (string-op operands, ID-gen keys)
  # --------------------------------------------------------------------------

  def encode_data(var) when is_binary(var) and binary_part(var, 0, 2) == "v:" do
    %{"@type" => "DataValue", "variable" => String.slice(var, 2..-1//1)}
  end

  def encode_data(value) when is_binary(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:string", "@value" => value}}
  end

  def encode_data(value) when is_integer(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:integer", "@value" => value}}
  end

  def encode_data(value) when is_float(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:decimal", "@value" => value}}
  end

  def encode_data(value) when is_boolean(value) do
    %{"@type" => "DataValue", "data" => %{"@type" => "xsd:boolean", "@value" => value}}
  end

  def encode_data(%{"@value" => _} = literal) do
    %{"@type" => "DataValue", "data" => literal}
  end

  def encode_data(value) when is_map(value), do: value

  # --------------------------------------------------------------------------
  # ArithmeticValue — arithmetic operands
  # --------------------------------------------------------------------------

  def encode_arithmetic(var) when is_binary(var) and binary_part(var, 0, 2) == "v:" do
    %{"@type" => "ArithmeticValue", "variable" => String.slice(var, 2..-1//1)}
  end

  def encode_arithmetic(value) when is_integer(value) do
    %{"@type" => "ArithmeticValue", "data" => %{"@type" => "xsd:integer", "@value" => value}}
  end

  def encode_arithmetic(value) when is_float(value) do
    %{"@type" => "ArithmeticValue", "data" => %{"@type" => "xsd:decimal", "@value" => value}}
  end

  def encode_arithmetic(%{"@value" => _} = literal) do
    %{"@type" => "ArithmeticValue", "data" => literal}
  end

  def encode_arithmetic(%TerminusDB.WOQL{} = q), do: encode(q)

  def encode_arithmetic(value) when is_map(value), do: value

  # --------------------------------------------------------------------------
  # Select variables — bare variable name strings (without v: prefix)
  # --------------------------------------------------------------------------

  def encode_select_var(var) when is_binary(var) and binary_part(var, 0, 2) == "v:" do
    String.slice(var, 2..-1//1)
  end

  def encode_select_var(var) when is_binary(var), do: var
end
