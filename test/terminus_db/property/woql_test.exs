defmodule TerminusDB.Property.WOQLTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TerminusDB.WOQL

  # Generate a variable name like "v:X"
  defp var_gen do
    map(string(:alphanumeric, min_length: 1, max_length: 10), fn name -> "v:#{name}" end)
  end

  # Generate a node (variable or constant IRI-like string)
  defp node_gen do
    one_of([
      var_gen(),
      string(:alphanumeric, min_length: 1, max_length: 20)
    ])
  end

  # Generate a value (variable, string, integer, float, boolean)
  defp value_gen do
    one_of([
      var_gen(),
      string(:alphanumeric, min_length: 1, max_length: 20),
      integer(0..1000),
      float(min: 0.0, max: 1000.0),
      boolean()
    ])
  end

  # Generate a leaf query (no sub-queries)
  defp leaf_query_gen do
    one_of([
      gen all(s <- node_gen(), p <- node_gen(), o <- value_gen()) do
        WOQL.triple(s, p, o)
      end,
      gen all(l <- value_gen(), r <- value_gen()) do
        WOQL.eq(l, r)
      end,
      gen all(n <- node_gen(), v <- var_gen()) do
        WOQL.type_of(n, v)
      end,
      gen all(id <- node_gen(), v <- var_gen()) do
        WOQL.read_document(id, v)
      end,
      constant(WOQL.true_()),
      gen all(
            s <- node_gen(),
            p <- node_gen(),
            o <- value_gen(),
            g <- string(:alphanumeric, min_length: 1, max_length: 10)
          ) do
        WOQL.quad(s, p, o, g)
      end,
      gen all(s <- node_gen(), p <- node_gen(), o <- value_gen()) do
        WOQL.add_triple(s, p, o)
      end,
      gen all(s <- node_gen(), p <- node_gen(), o <- value_gen()) do
        WOQL.delete_triple(s, p, o)
      end,
      gen all(l <- value_gen(), r <- value_gen()) do
        WOQL.less(l, r)
      end,
      gen all(l <- value_gen(), r <- value_gen()) do
        WOQL.greater(l, r)
      end
    ])
  end

  # Generate a query tree (with nesting up to depth 2)
  defp query_gen(depth \\ 0)

  defp query_gen(depth) when depth >= 2 do
    leaf_query_gen()
  end

  defp query_gen(depth) do
    one_of([
      leaf_query_gen(),
      gen all(queries <- list_of(query_gen(depth + 1), min_length: 1, max_length: 3)) do
        WOQL.and_(queries)
      end,
      gen all(queries <- list_of(query_gen(depth + 1), min_length: 1, max_length: 3)) do
        WOQL.or_(queries)
      end,
      gen all(q <- query_gen(depth + 1)) do
        WOQL.not_(q)
      end,
      gen all(q <- query_gen(depth + 1)) do
        WOQL.opt(q)
      end,
      gen all(
            vars <- list_of(var_gen(), min_length: 1, max_length: 3),
            q <- query_gen(depth + 1)
          ) do
        WOQL.select(vars, q)
      end,
      gen all(n <- integer(0..100), q <- query_gen(depth + 1)) do
        WOQL.limit(n, q)
      end,
      gen all(n <- integer(0..100), q <- query_gen(depth + 1)) do
        WOQL.start(n, q)
      end
    ])
  end

  property "to_jsonld ∘ from_jsonld is identity for random queries" do
    check all(q <- query_gen()) do
      jsonld = WOQL.to_jsonld(q)
      decoded = WOQL.from_jsonld(jsonld)

      assert decoded == q, """
      Round-trip failed.
      Original: #{inspect(q)}
      JSON-LD:  #{inspect(jsonld)}
      Decoded:  #{inspect(decoded)}
      """
    end
  end

  property "every variable in encoded JSON-LD has a variable key" do
    check all(q <- query_gen()) do
      jsonld = WOQL.to_jsonld(q)
      assert_variables_have_variable_key(jsonld)
    end
  end

  property "every literal in encoded JSON-LD has a data key with @value" do
    check all(q <- query_gen()) do
      jsonld = WOQL.to_jsonld(q)
      assert_literals_have_value(jsonld)
    end
  end

  defp assert_variables_have_variable_key(map) when is_map(map) do
    if Map.get(map, "@type") in ["NodeValue", "Value", "DataValue", "ArithmeticValue"] do
      if Map.has_key?(map, "variable") do
        assert is_binary(map["variable"])
      end
    end

    Enum.each(map, fn {_k, v} -> assert_variables_have_variable_key(v) end)
  end

  defp assert_variables_have_variable_key(list) when is_list(list) do
    Enum.each(list, &assert_variables_have_variable_key/1)
  end

  defp assert_variables_have_variable_key(_), do: :ok

  defp assert_literals_have_value(map) when is_map(map) do
    if Map.get(map, "@type") in ["Value", "DataValue", "ArithmeticValue"] and
         Map.has_key?(map, "data") do
      data = map["data"]

      if is_map(data) do
        assert Map.has_key?(data, "@value"), "Literal data missing @value: #{inspect(data)}"
      end
    end

    Enum.each(map, fn {_k, v} -> assert_literals_have_value(v) end)
  end

  defp assert_literals_have_value(list) when is_list(list) do
    Enum.each(list, &assert_literals_have_value/1)
  end

  defp assert_literals_have_value(_), do: :ok
end
