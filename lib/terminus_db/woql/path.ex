defmodule TerminusDB.WOQL.Path do
  @moduledoc false

  # Path pattern parser and structured builders for WOQL path queries.
  #
  # Supports two modes:
  #   1. String-compiled: path("v:S", "<friend*{1,3}", "v:O") — the pattern
  #      string is tokenized and parsed into a Path AST.
  #   2. Structured: path("v:S", path_star(path_pred("friend")), "v:O") —
  #      builds the AST compositionally.
  #
  # Grammar:
  #   pattern      := or
  #   or           := sequence ('|' sequence)*
  #   sequence     := step+
  #   step         := atom quantifier?
  #   quantifier   := '*' | '+' | '{' int (',' int?)? '}'
  #   atom         := predicate | '(' or ')' | inverse
  #   inverse      := '<' predicate
  #   predicate    := name | '.'
  #
  # AST nodes are tagged tuples:
  #   {:pred, name}           — PathPredicate
  #   {:any}                  — PathPredicate (any predicate, ".")
  #   {:or, [nodes]}          — PathOr
  #   {:seq, [nodes]}         — PathSequence
  #   {:star, node}           — PathStar
  #   {:plus, node}           — PathPlus
  #   {:times, node, from, to} — PathTimes
  #   {:inverse, name}        — InversePathPredicate

  # --------------------------------------------------------------------------
  # Structured builders
  # --------------------------------------------------------------------------

  @doc """
  Builds a path predicate node for the given predicate name.
  """
  @spec path_pred(String.t()) :: tuple()
  def path_pred(name) when is_binary(name), do: {:pred, name}

  @doc """
  Builds a path "any predicate" node (matches `.` in the string grammar).
  """
  @spec path_any :: tuple()
  def path_any, do: {:any}

  @doc """
  Builds a path sequence — each step is traversed in order.
  """
  @spec path_seq([tuple()]) :: tuple()
  def path_seq(steps) when is_list(steps), do: {:seq, steps}

  @doc """
  Builds a path alternation — any branch may be taken.
  """
  @spec path_or([tuple()]) :: tuple()
  def path_or(branches) when is_list(branches), do: {:or, branches}

  @doc """
  Builds a path star — zero or more repetitions.
  """
  @spec path_star(tuple()) :: tuple()
  def path_star(node), do: {:star, node}

  @doc """
  Builds a path plus — one or more repetitions.
  """
  @spec path_plus(tuple()) :: tuple()
  def path_plus(node), do: {:plus, node}

  @doc """
  Builds a path times — `from` to `to` repetitions. `to` may be `nil` for
  unbounded.
  """
  @spec path_times(tuple(), non_neg_integer(), non_neg_integer() | nil) :: tuple()
  def path_times(node, from, to \\ nil), do: {:times, node, from, to}

  @doc """
  Builds an inverse path — traverses the predicate in reverse direction.
  """
  @spec path_inverse(String.t()) :: tuple()
  def path_inverse(name) when is_binary(name), do: {:inverse, name}

  # --------------------------------------------------------------------------
  # String parser
  # --------------------------------------------------------------------------

  @doc """
  Parses a path pattern string into a Path AST.

  ## Examples

      iex> TerminusDB.WOQL.Path.parse("friend")
      {:pred, "friend"}

      iex> TerminusDB.WOQL.Path.parse("friend*")
      {:star, {:pred, "friend"}}

      iex> TerminusDB.WOQL.Path.parse("<friend")
      {:inverse, "friend"}

      iex> TerminusDB.WOQL.Path.parse("friend|foe")
      {:or, [{:pred, "friend"}, {:pred, "foe"}]}

  """
  @spec parse(String.t()) :: tuple()
  def parse(pattern) when is_binary(pattern) do
    tokens = tokenize(pattern)
    {ast, []} = parse_or(tokens)
    ast
  end

  defp tokenize(pattern), do: tokenize(pattern, [], "")

  defp tokenize("", tokens, acc), do: Enum.reverse(reverse_push(acc, tokens))

  defp tokenize(<<c::utf8, rest::binary>>, tokens, acc)
       when c in [?|, ?(, ?), ?*, ?+, ?{, ?}, ?<, ?.] do
    tokens = reverse_push(acc, tokens)
    char_token = char_to_token(<<c::utf8>>)
    tokenize(rest, [char_token | tokens], "")
  end

  defp tokenize(<<c::utf8, rest::binary>>, tokens, acc) when c == ?, do
    tokens = reverse_push(acc, tokens)
    tokenize(rest, tokens, "")
  end

  defp tokenize(<<c::utf8, rest::binary>>, tokens, acc) do
    tokenize(rest, tokens, <<acc::binary, c::utf8>>)
  end

  defp char_to_token("|"), do: :pipe
  defp char_to_token("("), do: :lparen
  defp char_to_token(")"), do: :rparen
  defp char_to_token("*"), do: :star
  defp char_to_token("+"), do: :plus
  defp char_to_token("{"), do: :lbrace
  defp char_to_token("}"), do: :rbrace
  defp char_to_token("<"), do: :lt
  defp char_to_token("."), do: :dot

  defp reverse_push("", tokens), do: tokens
  defp reverse_push(acc, tokens), do: [{:name, acc} | tokens]

  # parse_or := sequence ('|' sequence)*
  defp parse_or(tokens) do
    {first, rest} = parse_seq(tokens)

    case rest do
      [:pipe | rest2] ->
        {second, rest3} = parse_or(rest2)
        {{:or, [first, second]}, rest3}

      _ ->
        {first, rest}
    end
  end

  # parse_seq := step+  (returns single step if only one, {:seq, [...]} if multiple)
  defp parse_seq(tokens), do: parse_seq(tokens, [])

  defp parse_seq(tokens, []) do
    case parse_step(tokens) do
      :no_match ->
        :no_match

      {step, rest} ->
        if peek_stop(rest) do
          {step, rest}
        else
          parse_seq(rest, [step])
        end
    end
  end

  defp parse_seq(tokens, acc) do
    case parse_step(tokens) do
      :no_match ->
        {{:seq, Enum.reverse(acc)}, tokens}

      {step, rest} ->
        if peek_stop(rest) do
          {{:seq, Enum.reverse([step | acc])}, rest}
        else
          parse_seq(rest, [step | acc])
        end
    end
  end

  defp peek_stop([]), do: true
  defp peek_stop([:pipe | _]), do: true
  defp peek_stop([:rparen | _]), do: true
  defp peek_stop(_), do: false

  # parse_step := atom quantifier?
  defp parse_step(tokens) do
    case parse_atom(tokens) do
      :no_match ->
        :no_match

      {atom, rest} ->
        case parse_quantifier(rest) do
          {{:star, nil}, rest2} -> {{:star, atom}, rest2}
          {{:plus, nil}, rest2} -> {{:plus, atom}, rest2}
          {{:times, nil, from, to}, rest2} -> {{:times, atom, from, to}, rest2}
          :no_match -> {atom, rest}
        end
    end
  end

  # parse_atom := predicate | '(' or ')' | inverse
  defp parse_atom([:lt, {:name, name} | rest]) do
    {{:inverse, name}, rest}
  end

  defp parse_atom([:lt, :dot | rest]) do
    {{:inverse, "."}, rest}
  end

  defp parse_atom([:lparen | rest]) do
    case parse_or(rest) do
      {ast, [:rparen | rest2]} -> {ast, rest2}
      _ -> :no_match
    end
  end

  defp parse_atom([:dot | rest]) do
    {{:any}, rest}
  end

  defp parse_atom([{:name, name} | rest]) do
    {{:pred, name}, rest}
  end

  defp parse_atom(_), do: :no_match

  # parse_quantifier := '*' | '+' | '{' int (',' int?)? '}'
  defp parse_quantifier([:star | rest]), do: {{:star, nil}, rest}
  defp parse_quantifier([:plus | rest]), do: {{:plus, nil}, rest}

  defp parse_quantifier([:lbrace, {:name, n} | rest]) do
    with {from, ""} <- Integer.parse(n),
         {result, rest2} <- parse_times_rest(rest, from) do
      {result, rest2}
    else
      _ -> :no_match
    end
  end

  defp parse_quantifier(_), do: :no_match

  defp parse_times_rest([{:name, m} | rest], from) do
    with {to, ""} <- Integer.parse(m),
         [:rbrace | rest2] <- rest do
      {{:times, nil, from, to}, rest2}
    else
      _ -> :no_match
    end
  end

  defp parse_times_rest([:rbrace | rest2], from) do
    {{:times, nil, from, nil}, rest2}
  end

  defp parse_times_rest(_, _), do: :no_match

  # --------------------------------------------------------------------------
  # AST → JSON-LD serialization
  # --------------------------------------------------------------------------

  @doc """
  Serializes a Path AST node to the WOQL JSON-LD wire format.
  """
  @spec to_jsonld(tuple()) :: map()
  def to_jsonld({:pred, name}) do
    %{"@type" => "PathPredicate", "predicate" => name}
  end

  def to_jsonld({:any}) do
    %{"@type" => "PathPredicate", "predicate" => "."}
  end

  def to_jsonld({:or, branches}) do
    %{"@type" => "PathOr", "or" => Enum.map(branches, &to_jsonld/1)}
  end

  def to_jsonld({:seq, steps}) do
    %{"@type" => "PathSequence", "sequence" => Enum.map(steps, &to_jsonld/1)}
  end

  def to_jsonld({:star, node}) do
    %{"@type" => "PathStar", "star" => to_jsonld(node)}
  end

  def to_jsonld({:plus, node}) do
    %{"@type" => "PathPlus", "plus" => to_jsonld(node)}
  end

  def to_jsonld({:times, node, from, to}) do
    base = %{"@type" => "PathTimes", "times" => to_jsonld(node), "from" => from}

    if to do
      Map.put(base, "to", to)
    else
      base
    end
  end

  def to_jsonld({:inverse, name}) do
    %{"@type" => "InversePathPredicate", "predicate" => name}
  end

  # --------------------------------------------------------------------------
  # JSON-LD → AST deserialization
  # --------------------------------------------------------------------------

  @doc """
  Deserializes a WOQL JSON-LD path pattern back into a Path AST.
  """
  @spec from_jsonld(map()) :: tuple()
  def from_jsonld(%{"@type" => "PathPredicate", "predicate" => "."}) do
    {:any}
  end

  def from_jsonld(%{"@type" => "PathPredicate", "predicate" => name}) do
    {:pred, name}
  end

  def from_jsonld(%{"@type" => "PathOr", "or" => branches}) do
    {:or, Enum.map(branches, &from_jsonld/1)}
  end

  def from_jsonld(%{"@type" => "PathSequence", "sequence" => steps}) do
    {:seq, Enum.map(steps, &from_jsonld/1)}
  end

  def from_jsonld(%{"@type" => "PathStar", "star" => node}) do
    {:star, from_jsonld(node)}
  end

  def from_jsonld(%{"@type" => "PathPlus", "plus" => node}) do
    {:plus, from_jsonld(node)}
  end

  def from_jsonld(%{"@type" => "PathTimes"} = m) do
    to = if m["to"], do: m["to"], else: nil
    {:times, from_jsonld(m["times"]), m["from"], to}
  end

  def from_jsonld(%{"@type" => "InversePathPredicate", "predicate" => name}) do
    {:inverse, name}
  end

  # --------------------------------------------------------------------------
  # Pattern normalization — accepts string or AST, returns AST
  # --------------------------------------------------------------------------

  @doc """
  Normalizes a pattern — if it's a string, parses it; if it's already an AST
  tuple, returns it as-is.
  """
  @spec normalize(String.t() | tuple()) :: tuple()
  def normalize(pattern) when is_binary(pattern), do: parse(pattern)
  def normalize(pattern) when is_tuple(pattern), do: pattern
end
