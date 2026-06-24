defmodule TerminusDB.Streaming do
  @moduledoc """
  Incremental decoding of TerminusDB concatenated-JSON response bodies.

  TerminusDB's document endpoint returns documents as *concatenated JSON*
  (multiple JSON objects back-to-back, not newline-delimited and not a JSON
  array) when the `as_list` query parameter is not set. This module provides a
  bracket/depth-aware splitter that incrementally parses chunks emitted by Req's
  streaming (`into:`) into a stream of decoded maps.

  Used by `TerminusDB.Document.stream/2` (ADR-0007). Note: `Document.stream/2`
  does not pass `as_list: true`, so the server returns concatenated JSON; do not
  enable `as_list` on a streaming call as this splitter does not handle JSON
  array bodies.
  """

  @doc """
  Returns a stream of decoded JSON maps from a Req response that delivers chunks
  to `into: :self`. The response body must be concatenated JSON objects (the
  TerminusDB default when `as_list` is not set); JSON array bodies are not
  supported.

  ## Options

  - `:timeout` — receive timeout in milliseconds between chunks. If no message
    arrives within this window, the stream halts (defaults to `15_000`).

  ## Examples

      # With a Req response streamed via `into: :self`:
      resp = Req.get!(req, url: "document/admin/mydb", into: :self)
      TerminusDB.Streaming.document_stream(resp) |> Enum.take(10)

  """
  @spec document_stream(Req.Response.t(), keyword()) :: Enumerable.t()
  def document_stream(%Req.Response{} = resp, opts \\ []) do
    timeout = opts[:timeout] || 15_000

    Stream.resource(
      fn -> {resp, <<>>, false, timeout} end,
      &next_document/1,
      fn _ -> :ok end
    )
  end

  @doc """
  Splits a binary accumulator of concatenated JSON into a list of complete JSON
  object binaries and the remaining buffer. Objects are split on top-level `}`
  that closes the initial `{`, respecting string literals and nested braces.

  If the buffer ends inside a string and the last byte is a lone `\\` (an
  incomplete escape sequence), the backslash is retained in the returned buffer
  so the caller can prepend the next chunk and complete the escape.
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

  # Lone trailing backslash inside a string at end of buffer: keep it in the
  # buffer so the next chunk can complete the escape sequence.
  defp do_split(<<"\\">>, _depth, true, acc_docs, current),
    do: {Enum.reverse(acc_docs), current <> "\\"}

  # String handling: toggle in_string on unescaped quotes.
  defp do_split(<<"\"", rest::binary>>, depth, in_string, acc_docs, current) do
    do_split(rest, depth, not in_string, acc_docs, current <> "\"")
  end

  # Any other byte: accumulate.
  defp do_split(<<byte, rest::binary>>, depth, in_string, acc_docs, current) do
    do_split(rest, depth, in_string, acc_docs, <<current::binary, byte>>)
  end

  # Stream iteration: pull messages from the async response, accumulate, split.
  defp next_document({resp, buffer, true, _timeout}) do
    {:halt, {resp, buffer, true, nil}}
  end

  defp next_document({resp, buffer, false, timeout}) do
    case Req.parse_message(
           resp,
           receive do
             message -> message
           after
             timeout -> :timeout
           end
         ) do
      {:ok, chunks} ->
        {docs, new_buffer} = process_chunks(chunks, buffer)
        decoded = Enum.map(docs, &Jason.decode!/1)
        done = Enum.member?(chunks, :done)
        {decoded, {resp, new_buffer, done, timeout}}

      {:error, _} ->
        {:halt, {resp, buffer, true, timeout}}

      :timeout ->
        # No chunk arrived within the timeout window; halt to avoid hanging.
        {:halt, {resp, buffer, true, timeout}}

      :unknown ->
        next_document({resp, buffer, false, timeout})
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
