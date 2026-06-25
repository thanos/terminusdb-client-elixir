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

  # Generate an arithmetic value (variable or number only)
  defp arith_value_gen do
    one_of([
      var_gen(),
      integer(0..1000),
      float(min: 0.0, max: 1000.0)
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
      end,
      gen all(l <- value_gen(), r <- value_gen()) do
        WOQL.gte(l, r)
      end,
      gen all(l <- value_gen(), r <- value_gen()) do
        WOQL.lte(l, r)
      end,
      gen all(el <- node_gen(), ty <- node_gen()) do
        WOQL.isa(el, ty)
      end,
      gen all(p <- node_gen(), c <- node_gen()) do
        WOQL.sub(p, c)
      end,
      gen all(v <- value_gen(), ty <- value_gen(), r <- value_gen()) do
        WOQL.cast(v, ty, r)
      end,
      gen all(args <- list_of(arith_value_gen(), min_length: 2, max_length: 4)) do
        WOQL.plus(args)
      end,
      gen all(args <- list_of(arith_value_gen(), min_length: 2, max_length: 4)) do
        WOQL.minus(args)
      end,
      gen all(args <- list_of(arith_value_gen(), min_length: 2, max_length: 4)) do
        WOQL.times(args)
      end,
      gen all(b <- arith_value_gen(), e <- arith_value_gen()) do
        WOQL.exp(b, e)
      end,
      gen all(v <- arith_value_gen()) do
        WOQL.floor(v)
      end,
      gen all(args <- list_of(arith_value_gen(), min_length: 2, max_length: 4)) do
        WOQL.eval(WOQL.plus(args), "v:Result")
      end,
      gen all(lst <- list_of(value_gen(), min_length: 1, max_length: 3), r <- var_gen()) do
        WOQL.concat(lst, r)
      end,
      gen all(l <- value_gen(), g <- value_gen(), r <- value_gen()) do
        WOQL.join(l, g, r)
      end,
      gen all(u <- value_gen(), t <- value_gen()) do
        WOQL.trim(u, t)
      end,
      gen all(l <- value_gen(), r <- value_gen()) do
        WOQL.upper(l, r)
      end,
      gen all(l <- value_gen(), r <- value_gen()) do
        WOQL.lower(l, r)
      end,
      gen all(lst <- value_gen(), len <- value_gen()) do
        WOQL.length(lst, len)
      end,
      gen all(d <- value_gen(), f <- value_gen(), v <- value_gen()) do
        WOQL.dot(d, f, v)
      end,
      gen all(m <- value_gen(), lst <- value_gen()) do
        WOQL.member(m, lst)
      end,
      gen all(a <- value_gen(), b <- value_gen(), r <- value_gen()) do
        WOQL.set_difference(a, b, r)
      end,
      gen all(a <- value_gen(), b <- value_gen(), r <- value_gen()) do
        WOQL.set_intersection(a, b, r)
      end,
      gen all(a <- value_gen(), b <- value_gen(), r <- value_gen()) do
        WOQL.set_union(a, b, r)
      end,
      gen all(e <- value_gen(), s <- value_gen()) do
        WOQL.set_member(e, s)
      end,
      gen all(lst <- value_gen(), r <- value_gen()) do
        WOQL.sum(lst, r)
      end,
      gen all(doc <- value_gen()) do
        WOQL.insert_document(doc)
      end,
      gen all(doc <- value_gen()) do
        WOQL.update_document(doc)
      end,
      gen all(id <- node_gen()) do
        WOQL.delete_document(id)
      end,
      gen all(g <- string(:alphanumeric, min_length: 1, max_length: 10), sz <- var_gen()) do
        WOQL.size(g, sz)
      end,
      gen all(g <- string(:alphanumeric, min_length: 1, max_length: 10), c <- var_gen()) do
        WOQL.triple_count(g, c)
      end,
      gen all(c <- string(:alphanumeric, min_length: 1, max_length: 10), q <- query_gen(2)) do
        WOQL.using(c, q)
      end,
      gen all(g <- string(:alphanumeric, min_length: 1, max_length: 10), q <- query_gen(2)) do
        WOQL.from(g, q)
      end,
      gen all(txt <- string(:alphanumeric, min_length: 1, max_length: 20), q <- query_gen(2)) do
        WOQL.comment(txt, q)
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
