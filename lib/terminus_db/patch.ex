defmodule TerminusDB.Patch do
  @moduledoc """
  A JSON-LD patch container for TerminusDB document diffs.

  A `Patch` holds the raw JSON-LD patch content produced by `TerminusDB.Diff`
  operations. It provides convenience projections for extracting the "before"
  and "after" (update) states from `SwapValue` operations.

  ## Quick start

      {:ok, patch} = TerminusDB.Diff.diff_object(config,
        before: %{"@id" => "Person/1", "name" => "old"},
        after: %{"@id" => "Person/1", "name" => "new"}
      )

      patch.update   # => %{"name" => "new"}
      patch.before   # => %{"name" => "old"}

  """

  @enforce_keys [:content]
  defstruct [:content]

  @type t :: %__MODULE__{content: map() | [map()]}

  @doc """
  Parses a JSON string into a `%Patch{}`.

  ## Examples

      iex> {:ok, patch} = TerminusDB.Patch.from_json(~s({"name": {"@op": "SwapValue", "@before": "old", "@after": "new"}}))
      iex> patch.content["name"]["@after"]
      "new"

  """
  @spec from_json(String.t()) :: {:ok, t()} | {:error, term()}
  def from_json(json_string) do
    case Jason.decode(json_string) do
      {:ok, content} when is_map(content) -> {:ok, %__MODULE__{content: content}}
      {:ok, content} when is_list(content) -> {:ok, %__MODULE__{content: content}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Parses a JSON string into a `%Patch{}`, or raises.

  ## Examples

      iex> patch = TerminusDB.Patch.from_json!(~s({"name": {"@op": "SwapValue", "@before": "old", "@after": "new"}}))
      iex> patch.content["name"]["@before"]
      "old"

  """
  @spec from_json!(String.t()) :: t()
  def from_json!(json_string) do
    case from_json(json_string) do
      {:ok, patch} -> patch
      {:error, error} -> raise ArgumentError, "invalid JSON: #{inspect(error)}"
    end
  end

  @doc """
  Serializes a `%Patch{}` to a JSON string.

  ## Examples

      iex> patch = %TerminusDB.Patch{content: %{"name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}}}
      iex> json = TerminusDB.Patch.to_json(patch)
      iex> is_binary(json)
      true

  """
  @spec to_json(t()) :: String.t()
  def to_json(%__MODULE__{content: content}) do
    Jason.encode!(content)
  end

  @doc """
  Extracts the "after" (updated) values from `SwapValue` operations,
  recursively.

  ## Examples

      iex> patch = %TerminusDB.Patch{content: %{"name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}}}
      iex> TerminusDB.Patch.update(patch)
      %{"name" => "new"}

  """
  @spec update(t()) :: map()
  def update(%__MODULE__{content: content}) do
    extract_after(content)
  end

  @doc """
  Extracts the "before" values from `SwapValue` operations, recursively.

  ## Examples

      iex> patch = %TerminusDB.Patch{content: %{"name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}}}
      iex> TerminusDB.Patch.before(patch)
      %{"name" => "old"}

  """
  @spec before(t()) :: map()
  def before(%__MODULE__{content: content}) do
    extract_before(content)
  end

  @doc """
  Creates a deep copy of the patch.

  ## Examples

      iex> patch = %TerminusDB.Patch{content: %{"name" => "value"}}
      iex> copy = TerminusDB.Patch.copy(patch)
      iex> copy == patch
      true

  """
  @spec copy(t()) :: t()
  def copy(%__MODULE__{content: content}) do
    %__MODULE__{content: deep_copy(content)}
  end

  defp extract_after(item) when is_map(item) do
    case item do
      %{"@op" => "SwapValue", "@after" => after_val} ->
        after_val

      _ ->
        Enum.reduce(item, %{}, fn {key, val}, acc ->
          case val do
            %{"@op" => "SwapValue", "@after" => after_val} ->
              Map.put(acc, key, after_val)

            v when is_map(v) ->
              extracted = extract_after(v)

              if map_size(extracted) > 0 do
                Map.put(acc, key, extracted)
              else
                acc
              end

            _ ->
              acc
          end
        end)
    end
  end

  defp extract_after(_), do: %{}

  defp extract_before(item) when is_map(item) do
    Enum.reduce(item, %{}, fn {key, val}, acc ->
      case val do
        %{"@op" => "SwapValue", "@before" => before_val} ->
          Map.put(acc, key, before_val)

        v when is_map(v) ->
          extracted = extract_before(v)

          if map_size(extracted) > 0 do
            Map.put(acc, key, extracted)
          else
            acc
          end

        v ->
          Map.put(acc, key, v)
      end
    end)
  end

  defp extract_before(_), do: %{}

  defp deep_copy(term) when is_map(term) do
    Map.new(term, fn {k, v} -> {k, deep_copy(v)} end)
  end

  defp deep_copy(term) when is_list(term) do
    Enum.map(term, &deep_copy/1)
  end

  defp deep_copy(term), do: term
end
