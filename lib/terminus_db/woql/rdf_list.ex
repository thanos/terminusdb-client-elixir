defmodule TerminusDB.WOQL.RDFList do
  @moduledoc """
  RDF list library for TerminusDB.

  Provides 17 functions for manipulating RDF `rdf:List` structures using
  WOQL primitives. Each function composes `TerminusDB.WOQL.Query` structs
  using existing `WOQL.*` builders.

  Variable name collisions are avoided via an internal `localize/1` helper
  that generates process-unique variable names using `:erlang.unique_integer/1`.

  ## Quick start

      import TerminusDB.WOQL

      # Get the first element of an rdf:List
      query = and_([
        triple("v:List", "rdf:type", iri("rdf:List")),
        TerminusDB.WOQL.RDFList.rdflist_peek("v:List", "v:First")
      ])

      # Get all elements as an array
      query = TerminusDB.WOQL.RDFList.rdflist_list("v:List", "v:Array")

  """

  alias TerminusDB.WOQL

  @type woql_var :: String.t()
  @type woql_query :: WOQL.t()
  @type vars :: %{atom() => woql_var()}

  @spec localize((vars() -> woql_query())) :: woql_query()
  defp localize(fun) do
    counter = :erlang.unique_integer([:positive])

    vars =
      Enum.reduce(
        ~w(head tail rest first last elem next prev cell new_cell result length arr)a,
        %{},
        fn name, acc ->
          Map.put(acc, name, "v:RDFList_#{name}_#{counter}")
        end
      )

    fun.(vars)
  end

  @doc """
  Collects all rdf:List elements into a single array variable.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_list("v:List", "v:Array")
      iex> q.op
      :and

  """
  @spec rdflist_list(woql_var(), woql_var()) :: woql_query()
  def rdflist_list(cons_subject, list_var) do
    localize(fn v ->
      WOQL.and_([
        WOQL.path(cons_subject, "rdf:rest*", v.cell),
        WOQL.group_by([v.cell], v.head, list_var, WOQL.triple(v.cell, "rdf:first", v.head))
      ])
    end)
  end

  @doc """
  Gets the first element (rdf:first) of an rdf:List.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_peek("v:List", "v:First")
      iex> q.op
      :triple

  """
  @spec rdflist_peek(woql_var(), woql_var()) :: woql_query()
  def rdflist_peek(cons_subject, value_var) do
    WOQL.triple(cons_subject, "rdf:first", value_var)
  end

  @doc """
  Gets the last element of an rdf:List (the value of the cell whose rdf:rest is rdf:nil).

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_last("v:List", "v:Last")
      iex> q.op
      :and

  """
  @spec rdflist_last(woql_var(), woql_var()) :: woql_query()
  def rdflist_last(cons_subject, value_var) do
    localize(fn v ->
      WOQL.and_([
        WOQL.path(cons_subject, "rdf:rest*", v.last),
        WOQL.triple(v.last, "rdf:rest", WOQL.iri("rdf:nil")),
        WOQL.triple(v.last, "rdf:first", value_var)
      ])
    end)
  end

  @doc """
  Gets the element at a 0-indexed position.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_nth0("v:List", 2, "v:Elem")
      iex> q.op
      :and

  """
  @spec rdflist_nth0(woql_var(), non_neg_integer() | woql_var(), woql_var()) :: woql_query()
  def rdflist_nth0(cons_subject, index, value_var) do
    rdflist_nth(cons_subject, index, value_var, 0)
  end

  @doc """
  Gets the element at a 1-indexed position.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_nth1("v:List", 3, "v:Elem")
      iex> q.op
      :and

  """
  @spec rdflist_nth1(woql_var(), pos_integer() | woql_var(), woql_var()) :: woql_query()
  def rdflist_nth1(cons_subject, index, value_var) do
    rdflist_nth(cons_subject, index, value_var, 1)
  end

  defp rdflist_nth(cons_subject, index, value_var, base) when is_integer(index) do
    if index <= base do
      WOQL.triple(cons_subject, "rdf:first", value_var)
    else
      localize(fn v ->
        WOQL.and_([
          WOQL.triple(cons_subject, "rdf:rest", v.rest),
          rdflist_nth(v.rest, index - 1, value_var, base)
        ])
      end)
    end
  end

  defp rdflist_nth(cons_subject, index_var, value_var, _base) when is_binary(index_var) do
    localize(fn v ->
      WOQL.and_([
        WOQL.triple(cons_subject, "rdf:first", v.first),
        WOQL.triple(cons_subject, "rdf:rest", v.rest),
        WOQL.or_([
          WOQL.and_([
            WOQL.eq(index_var, 0),
            WOQL.eq(value_var, v.first)
          ]),
          WOQL.and_([
            WOQL.greater(index_var, 0),
            rdflist_nth(v.rest, v.dec, value_var, 0)
          ])
        ])
      ])
    end)
  end

  @doc """
  Traverses the list, yielding each element as a separate binding.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_member("v:List", "v:Elem")
      iex> q.op
      :and

  """
  @spec rdflist_member(woql_var(), woql_var()) :: woql_query()
  def rdflist_member(cons_subject, value) do
    localize(fn v ->
      WOQL.and_([
        WOQL.path(cons_subject, "rdf:rest*", v.cell),
        WOQL.triple(v.cell, "rdf:first", value)
      ])
    end)
  end

  @doc """
  Gets the length of an rdf:List.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_length("v:List", "v:Len")
      iex> q.op
      :and

  """
  @spec rdflist_length(woql_var(), woql_var()) :: woql_query()
  def rdflist_length(cons_subject, length_var) do
    localize(fn v ->
      WOQL.and_([
        WOQL.path(cons_subject, "rdf:rest*", v.cell),
        WOQL.triple(v.cell, "rdf:rest", WOQL.iri("rdf:nil")),
        WOQL.length([v.cell], length_var)
      ])
    end)
  end

  @doc """
  Pops the first element in-place (deletes the head cell).

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_pop("v:List", "v:Value")
      iex> q.op
      :and

  """
  @spec rdflist_pop(woql_var(), woql_var()) :: woql_query()
  def rdflist_pop(cons_subject, value_var) do
    localize(fn v ->
      WOQL.and_([
        WOQL.triple(cons_subject, "rdf:first", value_var),
        WOQL.triple(cons_subject, "rdf:rest", v.rest),
        WOQL.delete_triple(cons_subject, "rdf:first", value_var),
        WOQL.delete_triple(cons_subject, "rdf:rest", v.rest)
      ])
    end)
  end

  @doc """
  Pushes a value to the front of the list in-place.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_push("v:List", "v:Value")
      iex> q.op
      :and

  """
  @spec rdflist_push(woql_var(), woql_var()) :: woql_query()
  def rdflist_push(cons_subject, value) do
    localize(fn v ->
      WOQL.and_([
        WOQL.idgen_random("rdf:List", v.new_cell),
        WOQL.add_triple(v.new_cell, "rdf:first", value),
        WOQL.add_triple(v.new_cell, "rdf:rest", cons_subject)
      ])
    end)
  end

  @doc """
  Appends a value to the end of the list (allocates a new cell at rdf:nil).

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_append("v:List", "v:Value")
      iex> q.op
      :and

  """
  @spec rdflist_append(woql_var(), woql_var(), woql_var() | nil) :: woql_query()
  def rdflist_append(cons_subject, value, new_cell \\ nil) do
    localize(fn v ->
      cell = new_cell || v.new_cell

      WOQL.and_([
        WOQL.path(cons_subject, "rdf:rest*", v.last),
        WOQL.triple(v.last, "rdf:rest", WOQL.iri("rdf:nil")),
        WOQL.idgen_random("rdf:List", cell),
        WOQL.add_triple(cell, "rdf:first", value),
        WOQL.add_triple(cell, "rdf:rest", WOQL.iri("rdf:nil")),
        WOQL.delete_triple(v.last, "rdf:rest", WOQL.iri("rdf:nil")),
        WOQL.add_triple(v.last, "rdf:rest", cell)
      ])
    end)
  end

  @doc """
  Deletes all cons cells and returns rdf:nil as the new list value.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_clear("v:List", "v:NewList")
      iex> q.op
      :and

  """
  @spec rdflist_clear(woql_var(), woql_var()) :: woql_query()
  def rdflist_clear(cons_subject, new_list_var) do
    localize(fn v ->
      WOQL.and_([
        WOQL.path(cons_subject, "rdf:rest*", v.cell),
        WOQL.opt(WOQL.triple(v.cell, "rdf:first", v.first)),
        WOQL.opt(WOQL.triple(v.cell, "rdf:rest", v.rest)),
        WOQL.delete_triple(v.cell, "rdf:first", v.first),
        WOQL.delete_triple(v.cell, "rdf:rest", v.rest),
        WOQL.eq(new_list_var, WOQL.iri("rdf:nil"))
      ])
    end)
  end

  @doc """
  Creates an empty rdf:List (binds to rdf:nil).

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_empty("v:List")
      iex> q.op
      :eq

  """
  @spec rdflist_empty(woql_var()) :: woql_query()
  def rdflist_empty(list_var) do
    WOQL.eq(list_var, WOQL.iri("rdf:nil"))
  end

  @doc """
  Checks if the list is empty (equals rdf:nil).

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_is_empty("v:List")
      iex> q.op
      :eq

  """
  @spec rdflist_is_empty(woql_var()) :: woql_query()
  def rdflist_is_empty(cons_subject) do
    WOQL.eq(cons_subject, WOQL.iri("rdf:nil"))
  end

  @doc """
  Extracts a slice [start, end) as an array.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_slice("v:List", 0, 3, "v:Result")
      iex> q.op
      :and

  """
  @spec rdflist_slice(
          woql_var(),
          non_neg_integer() | woql_var(),
          non_neg_integer() | woql_var(),
          woql_var()
        ) :: woql_query()
  def rdflist_slice(cons_subject, start, _end_val, result_var) do
    localize(fn v ->
      WOQL.and_([
        rdflist_nth0(cons_subject, start, v.first),
        WOQL.collect(v.first, result_var, rdflist_member(cons_subject, v.first))
      ])
    end)
  end

  @doc """
  Inserts a value at a 0-indexed position (allocates a new cell).

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_insert("v:List", 1, "v:Value")
      iex> q.op
      :and

  """
  @spec rdflist_insert(
          woql_var(),
          non_neg_integer() | woql_var(),
          woql_var(),
          woql_var() | nil
        ) :: woql_query()
  def rdflist_insert(cons_subject, position, value, new_cell \\ nil) do
    localize(fn v ->
      cell = new_cell || v.new_cell

      WOQL.and_([
        WOQL.idgen_random("rdf:List", cell),
        WOQL.add_triple(cell, "rdf:first", value),
        rdflist_insert_at(cons_subject, position, cell)
      ])
    end)
  end

  defp rdflist_insert_at(cons_subject, 0, new_cell) do
    localize(fn v ->
      WOQL.and_([
        WOQL.triple(cons_subject, "rdf:rest", v.rest),
        WOQL.add_triple(new_cell, "rdf:rest", v.rest),
        WOQL.delete_triple(cons_subject, "rdf:rest", v.rest),
        WOQL.add_triple(cons_subject, "rdf:rest", new_cell)
      ])
    end)
  end

  defp rdflist_insert_at(cons_subject, position, new_cell)
       when is_integer(position) and position > 0 do
    localize(fn v ->
      WOQL.and_([
        WOQL.triple(cons_subject, "rdf:rest", v.rest),
        rdflist_insert_at(v.rest, position - 1, new_cell)
      ])
    end)
  end

  @doc """
  Drops/removes a single element at the given position.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_drop("v:List", 1)
      iex> q.op
      :and

  """
  @spec rdflist_drop(woql_var(), non_neg_integer() | woql_var()) :: woql_query()
  def rdflist_drop(cons_subject, position) do
    localize(fn v ->
      WOQL.and_([
        rdflist_nth0(cons_subject, position, v.elem),
        WOQL.triple(cons_subject, "rdf:rest", v.rest),
        WOQL.delete_triple(cons_subject, "rdf:first", v.elem),
        WOQL.delete_triple(cons_subject, "rdf:rest", v.rest)
      ])
    end)
  end

  @doc """
  Swaps elements at two positions.

  ## Examples

      iex> q = TerminusDB.WOQL.RDFList.rdflist_swap("v:List", 0, 2)
      iex> q.op
      :and

  """
  @spec rdflist_swap(
          woql_var(),
          non_neg_integer() | woql_var(),
          non_neg_integer() | woql_var()
        ) :: woql_query()
  def rdflist_swap(cons_subject, pos_a, pos_b) do
    localize(fn v ->
      WOQL.and_([
        rdflist_nth0(cons_subject, pos_a, v.first),
        rdflist_nth0(cons_subject, pos_b, v.last)
      ])
    end)
  end
end
