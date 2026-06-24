defmodule TerminusDB.DocumentTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Document, Error}
  import TerminusDB.Test.Helpers

  defp db_config(adapter) do
    Config.with_database(Config.new(endpoint: "http://localhost:6363", adapter: adapter), "mydb")
  end

  describe "insert/3" do
    test "POSTs to document/:org/:db with the document as JSON body" do
      test = self()
      adapter = capture(test, ok(%{"@type" => "api:InsertResponse"}))

      assert {:ok, _} =
               Document.insert(db_config(adapter), %{"@type" => "Person", "name" => "Alice"},
                 author: "admin",
                 message: "add Alice"
               )

      req = last_request()
      assert req.method == :post
      assert req.url.path == "/api/document/admin/mydb"

      assert {:ok, body} = Jason.decode(req.body)
      assert body == %{"@type" => "Person", "name" => "Alice"}

      assert req.url.query =~ "graph_type=instance"
      assert req.url.query =~ "author=admin"
      assert req.url.query =~ "message=add+Alice"
    end

    test "supports a list of documents" do
      test = self()
      adapter = capture(test, ok())

      Document.insert(
        db_config(adapter),
        [
          %{"@type" => "Person", "name" => "Alice"},
          %{"@type" => "Person", "name" => "Bob"}
        ],
        author: "admin",
        message: "add people"
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert is_list(body)
      assert length(body) == 2
    end

    test "passes full_replace and raw_json params" do
      test = self()
      adapter = capture(test, ok())

      Document.insert(db_config(adapter), %{"@type" => "X"},
        author: "a",
        message: "m",
        full_replace: true,
        raw_json: true
      )

      req = last_request()
      assert req.url.query =~ "full_replace=true"
      assert req.url.query =~ "raw_json=true"
    end

    test "targets the schema graph when graph_type: :schema" do
      test = self()
      adapter = capture(test, ok())

      Document.insert(db_config(adapter), %{"@type" => "Class"},
        author: "a",
        message: "m",
        graph_type: :schema
      )

      req = last_request()
      assert req.url.query =~ "graph_type=schema"
    end

    test "honors :organization override" do
      test = self()
      adapter = capture(test, ok())

      Document.insert(db_config(adapter), %{"@type" => "X"},
        author: "a",
        message: "m",
        organization: "acme"
      )

      req = last_request()
      assert req.url.path == "/api/document/acme/mydb"
    end

    test "raises when no database is scoped in config" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)

      assert_raise Error, fn ->
        Document.insert(config, %{"@type" => "X"}, author: "a", message: "m")
      end
    end
  end

  describe "insert!/3" do
    test "returns the response body on success" do
      adapter = fn req -> {req, ok(%{"@type" => "api:InsertResponse"})} end

      assert %{"@type" => "api:InsertResponse"} =
               Document.insert!(db_config(adapter), %{"@type" => "X"}, author: "a", message: "m")
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(400, %{"@type" => "api:bad"})} end

      assert_raise Error, fn ->
        Document.insert!(db_config(adapter), %{"@type" => "X"}, author: "a", message: "m")
      end
    end
  end

  describe "get/2" do
    test "GETs document/:org/:db with graph_type param" do
      test = self()
      adapter = capture(test, ok([%{"@type" => "Person", "name" => "Alice"}]))

      assert {:ok, _} = Document.get(db_config(adapter))
      req = last_request()
      assert req.method == :get
      assert req.url.path == "/api/document/admin/mydb"
      assert req.url.query =~ "graph_type=instance"
    end

    test "passes :id, :type, :skip, :count params" do
      test = self()
      adapter = capture(test, ok())

      Document.get(db_config(adapter),
        id: "Person/Alice",
        type: "Person",
        skip: 5,
        count: 10,
        as_list: true,
        unfold: false,
        compress_ids: false
      )

      req = last_request()
      q = req.url.query
      assert q =~ "id=Person%2FAlice"
      assert q =~ "type=Person"
      assert q =~ "skip=5"
      assert q =~ "count=10"
      assert q =~ "as_list=true"
    end

    test "sends unfold=false, minimized=false, compress_ids=false when explicitly disabled" do
      test = self()
      adapter = capture(test, ok([]))

      Document.get(db_config(adapter),
        unfold: false,
        minimized: false,
        compress_ids: false,
        as_list: false
      )

      req = last_request()
      q = req.url.query
      # These are tri-state params (server defaults to true); an explicit false
      # must be sent to override the default.
      assert q =~ "unfold=false"
      assert q =~ "minimized=false"
      assert q =~ "compress_ids=false"
      assert q =~ "as_list=false"
    end

    test "honors :organization override" do
      test = self()
      adapter = capture(test, ok())

      Document.get(db_config(adapter), organization: "acme")
      req = last_request()
      assert req.url.path == "/api/document/acme/mydb"
    end
  end

  describe "get!/2" do
    test "returns the body on success" do
      adapter = fn req -> {req, ok([%{"@id" => "Person/Alice"}])} end
      assert Document.get!(db_config(adapter)) == [%{"@id" => "Person/Alice"}]
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end
      assert_raise Error, fn -> Document.get!(db_config(adapter), id: "missing") end
    end
  end

  describe "query/3" do
    test "GETs document/:org/:db with the template as JSON body" do
      test = self()
      adapter = capture(test, ok([%{"@type" => "Person", "age" => 30}]))

      assert {:ok, _} = Document.query(db_config(adapter), %{"@type" => "Person", "age" => 30})
      req = last_request()
      assert req.method == :get

      assert {:ok, body} = Jason.decode(req.body)
      assert body == %{"@type" => "Person", "age" => 30}
    end

    test "passes :skip, :count, and :as_list params" do
      test = self()
      adapter = capture(test, ok([]))

      Document.query(db_config(adapter), %{"@type" => "Person"},
        skip: 5,
        count: 10,
        as_list: true
      )

      req = last_request()
      assert req.url.query =~ "skip=5"
      assert req.url.query =~ "count=10"
      assert req.url.query =~ "as_list=true"
    end

    test "targets the schema graph when graph_type: :schema" do
      test = self()
      adapter = capture(test, ok([]))

      Document.query(db_config(adapter), %{"@type" => "Class"}, graph_type: :schema)

      req = last_request()
      assert req.url.query =~ "graph_type=schema"
    end

    test "returns an :api error on failure" do
      adapter = fn req -> {req, resp(400, %{"@type" => "api:bad"})} end

      assert {:error, %Error{reason: :api}} =
               Document.query(db_config(adapter), %{"@type" => "X"})
    end
  end

  describe "query!/3" do
    test "returns the response body on success" do
      adapter = fn req -> {req, ok([%{"@type" => "Person", "name" => "Alice"}])} end

      assert [%{"name" => "Alice"}] =
               Document.query!(db_config(adapter), %{"@type" => "Person"})
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(400, %{"@type" => "api:bad"})} end

      assert_raise Error, fn ->
        Document.query!(db_config(adapter), %{"@type" => "X"})
      end
    end
  end

  describe "replace/3" do
    test "PUTs document/:org/:db with the document as JSON body" do
      test = self()
      adapter = capture(test, ok())

      Document.replace(db_config(adapter), %{"@id" => "Person/Alice", "name" => "Alicia"},
        author: "a",
        message: "rename"
      )

      req = last_request()
      assert req.method == :put
      assert {:ok, body} = Jason.decode(req.body)
      assert body["name"] == "Alicia"
    end

    test "passes create and raw_json params" do
      test = self()
      adapter = capture(test, ok())

      Document.replace(db_config(adapter), %{"@type" => "X"},
        author: "a",
        message: "m",
        create: true,
        raw_json: true
      )

      req = last_request()
      assert req.url.query =~ "create=true"
      assert req.url.query =~ "raw_json=true"
    end

    test "targets the schema graph when graph_type: :schema" do
      test = self()
      adapter = capture(test, ok())

      Document.replace(db_config(adapter), %{"@type" => "Class"},
        author: "a",
        message: "m",
        graph_type: :schema
      )

      req = last_request()
      assert req.url.query =~ "graph_type=schema"
    end

    test "returns an :api error on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end

      assert {:error, %Error{reason: :api}} =
               Document.replace(db_config(adapter), %{"@id" => "missing"},
                 author: "a",
                 message: "m"
               )
    end
  end

  describe "replace!/3" do
    test "returns the response body on success" do
      adapter = fn req -> {req, ok(%{"@id" => "Person/Alice", "name" => "Alicia"})} end

      assert %{"name" => "Alicia"} =
               Document.replace!(
                 db_config(adapter),
                 %{"@id" => "Person/Alice", "name" => "Alicia"},
                 author: "a",
                 message: "rename"
               )
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end

      assert_raise Error, fn ->
        Document.replace!(db_config(adapter), %{"@id" => "missing"}, author: "a", message: "m")
      end
    end
  end

  describe "delete/2" do
    test "DELETEs document/:org/:db with author and message" do
      test = self()
      adapter = capture(test, ok())

      assert {:ok, _} = Document.delete(db_config(adapter), author: "a", message: "remove")
      req = last_request()
      assert req.method == :delete
      assert req.url.query =~ "author=a"
      assert req.url.query =~ "message=remove"
    end

    test "passes :id and :nuke params" do
      test = self()
      adapter = capture(test, ok())

      Document.delete(db_config(adapter),
        id: "Person/Alice",
        nuke: true,
        author: "a",
        message: "m"
      )

      req = last_request()
      assert req.url.query =~ "id=Person%2FAlice"
      assert req.url.query =~ "nuke=true"
    end
  end

  describe "delete!/2" do
    test "returns the response body on success" do
      adapter = fn req -> {req, ok(%{"api:status" => "api:success"})} end

      assert %{"api:status" => "api:success"} =
               Document.delete!(db_config(adapter), id: "Person/Alice", author: "a", message: "m")
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end

      assert_raise Error, fn ->
        Document.delete!(db_config(adapter), id: "missing", author: "a", message: "m")
      end
    end
  end

  describe "stream/2" do
    test "builds the correct request path and params" do
      test = self()

      adapter = fn req ->
        send(test, {:request, req})
        {req, ok([%{"@type" => "Person"}])}
      end

      _ = Document.stream(db_config(adapter), type: "Person")

      req = last_request()
      assert req.method == :get
      assert req.url.path == "/api/document/admin/mydb"
      assert req.url.query =~ "type=Person"
    end

    test "raises TerminusDB.Error on a non-2xx response" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end

      assert_raise Error, fn ->
        Document.stream(db_config(adapter), type: "Person")
      end
    end

    test "raises TerminusDB.Error on a transport error" do
      adapter = fn req -> {req, Req.TransportError.exception(reason: :econnrefused)} end

      assert_raise Error, fn ->
        Document.stream(db_config(adapter), type: "Person")
      end
    end
  end
end
