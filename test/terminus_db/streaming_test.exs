defmodule TerminusDB.StreamingTest do
  use ExUnit.Case, async: true

  alias TerminusDB.Streaming

  describe "split_concatenated/1" do
    test "splits complete concatenated JSON objects" do
      buffer = ~s({"a":1}{"b":2}{"c":3})
      {docs, rest} = Streaming.split_concatenated(buffer)
      assert docs == [~s({"a":1}), ~s({"b":2}), ~s({"c":3})]
      assert rest == ""
    end

    test "leaves incomplete trailing object in the buffer" do
      buffer = ~s({"a":1}{"b":2)
      {docs, rest} = Streaming.split_concatenated(buffer)
      assert docs == [~s({"a":1})]
      assert rest == ~s({"b":2)
    end

    test "handles nested braces" do
      buffer = ~s({"a":{"x":1}}{"b":2})
      {docs, rest} = Streaming.split_concatenated(buffer)
      assert docs == [~s({"a":{"x":1}}), ~s({"b":2})]
      assert rest == ""
    end

    test "handles braces inside string literals" do
      buffer = ~s({"a":"}hello{"}{"b":2})
      {docs, rest} = Streaming.split_concatenated(buffer)
      assert docs == [~s({"a":"}hello{"}), ~s({"b":2})]
      assert rest == ""
    end

    test "handles escaped quotes inside strings" do
      # JSON: {"a":"he said \"hi\""}{"b":2}{"c":3}
      buffer = ~s({"a":"he said \\"hi\\""}{"b":2}{"c":3})
      {docs, rest} = Streaming.split_concatenated(buffer)
      assert docs == [~s({"a":"he said \\"hi\\""}), ~s({"b":2}), ~s({"c":3})]
      assert rest == ""
    end

    test "returns empty list and buffer for empty input" do
      {docs, rest} = Streaming.split_concatenated("")
      assert docs == []
      assert rest == ""
    end

    test "handles incomplete first object" do
      buffer = ~s({"a":1)
      {docs, rest} = Streaming.split_concatenated(buffer)
      assert docs == []
      assert rest == ~s({"a":1)
    end

    test "handles arrays as values" do
      buffer = ~s({"a":[1,2,3]}{"b":[]})
      {docs, rest} = Streaming.split_concatenated(buffer)
      assert docs == [~s({"a":[1,2,3]}), ~s({"b":[]})]
      assert rest == ""
    end

    test "decodes the split objects as maps" do
      buffer = ~s({"@type":"Person","name":"Alice"}{"@type":"Person","name":"Bob"})
      {docs, _rest} = Streaming.split_concatenated(buffer)

      maps = Enum.map(docs, &Jason.decode!/1)

      assert maps == [
               %{"@type" => "Person", "name" => "Alice"},
               %{"@type" => "Person", "name" => "Bob"}
             ]
    end
  end

  describe "document_stream/1" do
    # Builds a Req.Response with a fake Req.Response.Async body whose
    # stream_fun decodes messages sent to the current process.
    #
    # The `messages` argument is a list of terms to send to the process mailbox.
    # Each message is received by the `receive` block in `next_document`, then
    # passed to `stream_fun`. The `stream_fun` returns `{:ok, chunks}` where
    # chunks is a keyword list like `[data: "..."]` or `[:done]`.
    #
    # We send a sequence of `{:data, binary}` chunks followed by `:done`, which
    # the stream_fun translates into the `{:ok, chunks}` / `:done` format Req uses.
    defp fake_async_response(chunks) do
      ref = make_ref()

      stream_fun = fn ^ref, message ->
        case message do
          {^ref, :data} -> {:ok, chunks}
          {^ref, :done} -> {:ok, [:done]}
          {^ref, {:error, reason}} -> {:error, reason}
          _ -> :unknown
        end
      end

      cancel_fun = fn ^ref -> :ok end

      async = %Req.Response.Async{
        pid: self(),
        ref: ref,
        stream_fun: stream_fun,
        cancel_fun: cancel_fun
      }

      Req.Response.new(status: 200, body: async)
    end

    # Sends a sequence of data chunks followed by a done signal.
    # Each `data` binary is sent as `{ref, :data}` and the stream_fun returns
    # `{:ok, [data: data]}`. A final `{ref, :done}` signals end of stream.
    defp send_chunks(ref, data_chunks) do
      for data <- data_chunks do
        send(self(), {ref, {:data, data}})
      end

      send(self(), {ref, :done})
    end

    # A stream_fun that reads the actual data from the message tuple.
    defp fake_async_response_with_data(data_chunks) do
      ref = make_ref()

      stream_fun = fn ^ref, message ->
        case message do
          {^ref, {:data, data}} -> {:ok, [data: data]}
          {^ref, :done} -> {:ok, [:done]}
          {^ref, {:error, reason}} -> {:error, reason}
          _ -> :unknown
        end
      end

      cancel_fun = fn ^ref -> :ok end

      async = %Req.Response.Async{
        pid: self(),
        ref: ref,
        stream_fun: stream_fun,
        cancel_fun: cancel_fun
      }

      send_chunks(ref, data_chunks)
      Req.Response.new(status: 200, body: async)
    end

    test "streams complete documents from a single chunk" do
      resp =
        fake_async_response_with_data([
          ~s({"@type":"Person","name":"Alice"}{"@type":"Person","name":"Bob"})
        ])

      docs = Enum.to_list(Streaming.document_stream(resp))

      assert Enum.map(docs, & &1["name"]) == ["Alice", "Bob"]
    end

    test "streams documents split across multiple chunks" do
      resp =
        fake_async_response_with_data([
          ~s({"@type":"Person","name":"Alice"}),
          ~s({"@type":"Person","name":"Bob"})
        ])

      docs = Enum.to_list(Streaming.document_stream(resp))

      assert Enum.map(docs, & &1["name"]) == ["Alice", "Bob"]
    end

    test "streams documents when a single document is split across chunks" do
      # A single document split mid-way through: the first chunk ends after
      # the "name" value, the second chunk completes the object.
      resp =
        fake_async_response_with_data([
          ~s({"@type":"Person","name":"Alice",),
          ~s("age":30})
        ])

      docs = Enum.to_list(Streaming.document_stream(resp))

      assert length(docs) == 1
      assert hd(docs)["name"] == "Alice"
      assert hd(docs)["age"] == 30
    end

    test "returns empty list when no documents are received" do
      resp = fake_async_response_with_data([])

      docs = Enum.to_list(Streaming.document_stream(resp))

      assert docs == []
    end

    test "streams documents with nested objects" do
      resp =
        fake_async_response_with_data([
          ~s({"@type":"Person","name":"Alice","address":{"city":"NYC"}}) <>
            ~s({"@type":"Person","name":"Bob","address":{"city":"LA"}})
        ])

      docs = Enum.to_list(Streaming.document_stream(resp))

      assert Enum.map(docs, & &1["name"]) == ["Alice", "Bob"]
      assert hd(docs)["address"]["city"] == "NYC"
    end

    test "halts on error from the stream" do
      ref = make_ref()

      stream_fun = fn ^ref, message ->
        case message do
          {^ref, {:data, data}} -> {:ok, [data: data]}
          {^ref, {:error, reason}} -> {:error, reason}
          _ -> :unknown
        end
      end

      async = %Req.Response.Async{
        pid: self(),
        ref: ref,
        stream_fun: stream_fun,
        cancel_fun: fn ^ref -> :ok end
      }

      send(self(), {ref, {:data, ~s({"name":"Alice"})}})
      send(self(), {ref, {:error, %RuntimeError{message: "connection reset"}}})

      resp = Req.Response.new(status: 200, body: async)

      docs = Enum.to_list(Streaming.document_stream(resp))

      # Should have received the one document before the error
      assert length(docs) == 1
      assert hd(docs)["name"] == "Alice"
    end

    test "processes trailers and other non-data chunks by ignoring them" do
      ref = make_ref()

      stream_fun = fn ^ref, message ->
        case message do
          {^ref, {:data, data}} -> {:ok, [data: data]}
          {^ref, :trailers} -> {:ok, [trailers: %{"x-custom" => "value"}]}
          {^ref, :done} -> {:ok, [:done]}
          _ -> :unknown
        end
      end

      async = %Req.Response.Async{
        pid: self(),
        ref: ref,
        stream_fun: stream_fun,
        cancel_fun: fn ^ref -> :ok end
      }

      send(self(), {ref, {:data, ~s({"name":"Alice"})}})
      send(self(), {ref, :trailers})
      send(self(), {ref, :done})

      resp = Req.Response.new(status: 200, body: async)

      docs = Enum.to_list(Streaming.document_stream(resp))

      assert length(docs) == 1
      assert hd(docs)["name"] == "Alice"
    end

    test "skips unknown messages and continues to real data" do
      ref = make_ref()

      stream_fun = fn ^ref, message ->
        case message do
          {^ref, {:data, data}} -> {:ok, [data: data]}
          {^ref, :done} -> {:ok, [:done]}
          _ -> :unknown
        end
      end

      async = %Req.Response.Async{
        pid: self(),
        ref: ref,
        stream_fun: stream_fun,
        cancel_fun: fn ^ref -> :ok end
      }

      # Send an unrelated message first, then the real data
      send(self(), {:some_other_message, :ignore_me})
      send(self(), {ref, {:data, ~s({"name":"Alice"})}})
      send(self(), {ref, :done})

      resp = Req.Response.new(status: 200, body: async)

      docs = Enum.to_list(Streaming.document_stream(resp))

      assert length(docs) == 1
      assert hd(docs)["name"] == "Alice"
    end
  end
end
