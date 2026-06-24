defmodule TerminusDB.Streaming do
  @moduledoc """
  Incremental decoding of TerminusDB concatenated-JSON response bodies.

  TerminusDB's document endpoint returns documents either as a JSON array or as
  *concatenated JSON* (multiple JSON objects back-to-back, not newline-delimited).
  This module provides a bracket/depth-aware splitter that incrementally parses
  chunks emitted by Req's streaming (`into:`) into a stream of decoded maps.

  Used by `TerminusDB.Document.stream/2` (ADR-0007).
  """

  @doc """
  Returns a stream of decoded JSON maps from a Req response that delivers chunks
  to `into: :self` (or a collectable). Accepts either a JSON array body or
  concatenated JSON objects.

  ## Examples

      # With a Req response streamed via `into: :self`:
      resp = Req.get!(req, url: "document/admin/mydb", into: :self)
      TerminusDB.Streaming.document_stream(resp) |> Enum.take(10)

  """
  @spec document_stream(Req.Response.t()) :: Enumerable.t()
  def document_stream(%Req.Response{} = resp) do
    Stream.resource(
      fn -> {resp, <<>>, false} end,
      &next_document/1,
      fn _ -> :ok end
    )
  end

  @doc """
  Splits a binary accumulator of concatenated JSON into a list of complete JSON
  object binaries and the remaining buffer. Objects are split on top-level `}`
  that closes the initial `{`, respecting string literals and nested braces.
  """
  @spec split_concatenated(binary()) :: {[binary()], binary()}
  def split_concatenated(buffer) when is_binary(buffer) do
    do_split(buffer, 0, false, [], <<>>)
  end

  # The accumulator walks the buffer, tracking depth and string state. When a
  # top-level object closes (depth returns to 0), the bytes consumed so far form
  # a complete JSON object.
  defp do_split(<<>>, 0, false, acc_docs, <<>>) when acc_docs == [],
    do: {[], <<>>}

  defp do_split(<<>>, 0, false, acc_docs, current) do
    if current == <<>> do
      {Enum.reverse(acc_docs), <<>>}
    else
      {Enum.reverse(acc_docs), current}
    end
  end

  defp do_split(<<>>, _depth, _in_string, acc_docs, current),
    do: {Enum.reverse(acc_docs), current}

  # Opening brace: increase depth (unless inside a string).
  defp do_split(<<"{", rest::binary>>, depth, false, acc_docs, current) do
    do_split(rest, depth + 1, false, acc_docs, current <> "{")
  end

  # Closing brace: decrease depth; if we hit 0, we have a complete object.
  defp do_split(<<"}", rest::binary>>, 1, false, acc_docs, current) do
    complete = current <> "}"
    do_split(rest, 0, false, [complete | acc_docs], <<>>)
  end

  defp do_split(<<"}", rest::binary>>, depth, false, acc_docs, current) when depth > 1 do
    do_split(rest, depth - 1, false, acc_docs, current <> "}")
  end

  # Escape sequence inside a string: consume the backslash and the next char.
  defp do_split(<<"\\", char, rest::binary>>, depth, true, acc_docs, current) do
    do_split(rest, depth, true, acc_docs, <<current::binary, ?\\, char>>)
  end

  # String handling: toggle in_string on unescaped quotes.
  defp do_split(<<"\"", rest::binary>>, depth, in_string, acc_docs, current) do
    do_split(rest, depth, not in_string, acc_docs, current <> "\"")
  end

  # Any other byte: accumulate.
  defp do_split(<<byte, rest::binary>>, depth, in_string, acc_docs, current) do
    do_split(rest, depth, in_string, acc_docs, <<current::binary, byte>>)
  end

  # Stream iteration: pull messages from the async response, accumulate, split.
  defp next_document({resp, buffer, true}) do
    {:halt, {resp, buffer, true}}
  end

  defp next_document({resp, buffer, false}) do
    case Req.parse_message(
           resp,
           receive do
             message -> message
           end
         ) do
      {:ok, chunks} ->
        {docs, new_buffer} = process_chunks(chunks, buffer)
        decoded = Enum.map(docs, &Jason.decode!/1)
        done = Enum.member?(chunks, :done)
        {decoded, {resp, new_buffer, done}}

      {:error, _} ->
        {:halt, {resp, buffer, true}}

      :unknown ->
        next_document({resp, buffer, false})
    end
  end

  defp process_chunks(chunks, buffer) do
    raw =
      Enum.reduce(chunks, buffer, fn
        {:data, data}, acc -> acc <> data
        _other, acc -> acc
      end)

    split_concatenated(raw)
  end
end
