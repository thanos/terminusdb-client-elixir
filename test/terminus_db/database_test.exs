defmodule TerminusDB.DatabaseTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Database, Error}
  import TerminusDB.Test.Helpers

  describe "create/3" do
    test "POSTs to db/:org/:db with label, comment, schema" do
      test = self()
      adapter = capture(test, ok())

      assert {:ok, %{"api:status" => "api:success"}} =
               Database.create(config(adapter), "mydb",
                 label: "My DB",
                 comment: "demo",
                 schema: true
               )

      req = last_request()
      assert req.method == :post
      assert URI.to_string(req.url) == "http://localhost:6363/api/db/admin/mydb"

      assert {:ok, body} = Jason.decode(req.body)
      assert body["label"] == "My DB"
      assert body["comment"] == "demo"
      assert body["schema"] == true
      refute Map.has_key?(body, "public")
      refute Map.has_key?(body, "prefixes")
    end

    test "defaults label to the db name and comment to empty" do
      test = self()
      adapter = capture(test, ok())

      Database.create(config(adapter), "mydb", schema: false)

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["label"] == "mydb"
      assert body["comment"] == ""
      assert body["schema"] == false
    end

    test "includes public and prefixes when given" do
      test = self()
      adapter = capture(test, ok())

      Database.create(config(adapter), "mydb",
        label: "L",
        public: true,
        prefixes: %{"@base" => "http://ex/"}
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["public"] == true
      assert body["prefixes"] == %{"@base" => "http://ex/"}
    end

    test "honors :organization override" do
      test = self()
      adapter = capture(test, ok())

      Database.create(config(adapter), "mydb", organization: "acme", label: "L")

      req = last_request()
      assert URI.to_string(req.url) == "http://localhost:6363/api/db/acme/mydb"
    end

    test "returns an :api error on DatabaseAlreadyExists" do
      body = %{
        "@type" => "api:DbCreateErrorResponse",
        "api:error" => %{"@type" => "api:DatabaseAlreadyExists"},
        "api:message" => "Database already exists.",
        "api:status" => "api:failure"
      }

      adapter = fn req -> {req, Req.Response.new(status: 400, body: body)} end

      assert {:error, %Error{reason: :api, api_type: "api:DatabaseAlreadyExists"}} =
               Database.create(config(adapter), "mydb", label: "L")
    end
  end

  describe "create!/3" do
    test "returns the response body on success" do
      test = self()

      adapter =
        capture(test, ok(%{"@type" => "api:DbCreateResponse", "api:status" => "api:success"}))

      assert %{"@type" => "api:DbCreateResponse", "api:status" => "api:success"} =
               Database.create!(config(adapter), "mydb", label: "L")
    end

    test "raises on failure" do
      adapter = fn req -> {req, Req.Response.new(status: 400, body: %{"@type" => "api:bad"})} end

      assert_raise TerminusDB.Error, fn ->
        Database.create!(config(adapter), "mydb", label: "L")
      end
    end
  end

  describe "delete/3" do
    test "DELETEs db/:org/:db" do
      test = self()
      adapter = capture(test, ok())

      assert {:ok, _} = Database.delete(config(adapter), "mydb")
      req = last_request()
      assert req.method == :delete
      assert URI.to_string(req.url) == "http://localhost:6363/api/db/admin/mydb"
      assert req.url.query == nil
    end

    test "passes force as a query param" do
      test = self()
      adapter = capture(test, ok())

      Database.delete(config(adapter), "mydb", force: true)
      req = last_request()
      assert req.url.query == "force=true"
    end

    test "honors :organization override" do
      test = self()
      adapter = capture(test, ok())

      Database.delete(config(adapter), "mydb", organization: "acme")
      req = last_request()
      assert URI.to_string(req.url) == "http://localhost:6363/api/db/acme/mydb"
    end
  end

  describe "delete!/3" do
    test "returns the response body on success" do
      adapter = fn req ->
        {req, ok(%{"@type" => "api:DbDeleteResponse", "api:status" => "api:success"})}
      end

      assert %{"@type" => "api:DbDeleteResponse"} = Database.delete!(config(adapter), "mydb")
    end

    test "raises on failure" do
      adapter = fn req ->
        {req, Req.Response.new(status: 404, body: %{"@type" => "api:DbDeleteErrorResponse"})}
      end

      assert_raise TerminusDB.Error, fn -> Database.delete!(config(adapter), "missing") end
    end
  end

  describe "info/3" do
    test "GETs db/:org/:db and returns the list" do
      test = self()
      details = [%{"@type" => "UserDatabase", "name" => "mydb"}]
      adapter = capture(test, Req.Response.new(status: 200, body: details))

      assert {:ok, ^details} = Database.info(config(adapter), "mydb")
      req = last_request()
      assert req.method == :get
      assert URI.to_string(req.url) == "http://localhost:6363/api/db/admin/mydb"
    end

    test "passes branches and verbose params" do
      test = self()
      adapter = capture(test, ok([]))

      Database.info(config(adapter), "mydb", branches: true, verbose: true)
      req = last_request()
      # Req may serialize query params in any order; assert both are present.
      query = req.url.query
      assert query =~ "branches=true"
      assert query =~ "verbose=true"
    end

    test "omits params when branches and verbose are false" do
      test = self()
      adapter = capture(test, ok([]))

      Database.info(config(adapter), "mydb", branches: false, verbose: false)
      req = last_request()
      assert req.url.query == nil
    end

    test "honors :organization override" do
      test = self()
      adapter = capture(test, ok([]))

      Database.info(config(adapter), "mydb", organization: "acme")
      req = last_request()
      assert URI.to_string(req.url) == "http://localhost:6363/api/db/acme/mydb"
    end

    test "forwards a non-boolean param value as-is" do
      test = self()
      adapter = capture(test, ok([]))

      # Exercises the generic maybe_param clause that forwards any non-nil,
      # non-false, non-true value verbatim.
      Database.info(config(adapter), "mydb", branches: "yes")
      req = last_request()
      assert req.url.query =~ "branches=yes"
    end
  end

  describe "info!/3" do
    test "returns the list on success" do
      details = [%{"@type" => "UserDatabase", "name" => "mydb"}]
      adapter = fn req -> {req, Req.Response.new(status: 200, body: details)} end

      assert ^details = Database.info!(config(adapter), "mydb")
    end

    test "raises on failure" do
      adapter = fn req ->
        {req, Req.Response.new(status: 404, body: %{"@type" => "api:NotFound"})}
      end

      assert_raise TerminusDB.Error, fn -> Database.info!(config(adapter), "missing") end
    end
  end

  describe "list/2" do
    test "GETs db/ and returns the list" do
      test = self()
      dbs = [%{"name" => "a"}, %{"name" => "b"}]
      adapter = capture(test, Req.Response.new(status: 200, body: dbs))

      assert {:ok, ^dbs} = Database.list(config(adapter))
      req = last_request()
      assert req.method == :get
      assert URI.to_string(req.url) == "http://localhost:6363/api/db"
    end

    test "passes verbose param" do
      test = self()
      adapter = capture(test, ok([]))

      Database.list(config(adapter), verbose: true)
      req = last_request()
      assert req.url.query =~ "verbose=true"
    end

    test "omits params when branches and verbose are false" do
      test = self()
      adapter = capture(test, ok([]))

      Database.list(config(adapter), branches: false, verbose: false)
      req = last_request()
      assert req.url.query == nil
    end
  end

  describe "list!/2" do
    test "returns the list on success" do
      dbs = [%{"name" => "a"}]
      adapter = fn req -> {req, Req.Response.new(status: 200, body: dbs)} end

      assert ^dbs = Database.list!(config(adapter))
    end

    test "raises on failure" do
      adapter = fn req ->
        {req, Req.Response.new(status: 401, body: %{"@type" => "api:Unauthorized"})}
      end

      assert_raise TerminusDB.Error, fn -> Database.list!(config(adapter)) end
    end
  end

  describe "exists?/3" do
    test "returns true on 200 and issues a HEAD to db/:org/:db" do
      test = self()

      adapter = fn req ->
        send(test, {:request, req})
        {req, Req.Response.new(status: 200, body: "")}
      end

      assert Database.exists?(config(adapter), "mydb") == true
      req = last_request()
      assert req.method == :head
      assert URI.to_string(req.url) == "http://localhost:6363/api/db/admin/mydb"
    end

    test "returns false on 404" do
      adapter = fn req -> {req, Req.Response.new(status: 404, body: "")} end
      assert Database.exists?(config(adapter), "missing") == false
    end

    test "honors :organization override" do
      test = self()

      adapter = fn req ->
        send(test, {:request, req})
        {req, Req.Response.new(status: 200, body: "")}
      end

      Database.exists?(config(adapter), "mydb", organization: "acme")
      req = last_request()
      assert URI.to_string(req.url) == "http://localhost:6363/api/db/acme/mydb"
    end

    test "raises on unexpected errors" do
      adapter = fn req ->
        {req, Req.Response.new(status: 401, body: %{"@type" => "api:Unauthorized"})}
      end

      assert_raise TerminusDB.Error, fn -> Database.exists?(config(adapter), "mydb") end
    end
  end

  describe "update/3" do
    test "PUTs db/:org/:db with the new metadata" do
      test = self()
      adapter = capture(test, ok())

      Database.update(config(adapter), "mydb", label: "New Label", comment: "updated")
      req = last_request()
      assert req.method == :put
      assert URI.to_string(req.url) == "http://localhost:6363/api/db/admin/mydb"

      assert {:ok, body} = Jason.decode(req.body)
      assert body["label"] == "New Label"
      assert body["comment"] == "updated"
    end

    test "includes public and prefixes when given" do
      test = self()
      adapter = capture(test, ok())

      Database.update(config(adapter), "mydb",
        label: "L",
        public: false,
        prefixes: %{"@base" => "http://ex/"}
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["public"] == false
      assert body["prefixes"] == %{"@base" => "http://ex/"}
    end

    test "honors :organization override" do
      test = self()
      adapter = capture(test, ok())

      Database.update(config(adapter), "mydb", organization: "acme", label: "L")
      req = last_request()
      assert URI.to_string(req.url) == "http://localhost:6363/api/db/acme/mydb"
    end

    test "returns an :api error on UnknownDatabase" do
      body = %{
        "@type" => "api:DbUpdateErrorResponse",
        "api:error" => %{"@type" => "api:UnknownDatabase"},
        "api:message" => "Unknown database: admin/missing",
        "api:status" => "api:not_found"
      }

      adapter = fn req -> {req, Req.Response.new(status: 404, body: body)} end

      assert {:error, %Error{reason: :api, api_type: "api:UnknownDatabase"}} =
               Database.update(config(adapter), "missing", label: "L")
    end
  end

  describe "update!/3" do
    test "returns the response body on success" do
      adapter = fn req ->
        {req, ok(%{"@type" => "api:DbUpdatedResponse", "api:status" => "api:success"})}
      end

      assert %{"@type" => "api:DbUpdatedResponse"} =
               Database.update!(config(adapter), "mydb", label: "L")
    end

    test "raises on failure" do
      adapter = fn req ->
        {req, Req.Response.new(status: 404, body: %{"@type" => "api:NotFound"})}
      end

      assert_raise TerminusDB.Error, fn ->
        Database.update!(config(adapter), "missing", label: "L")
      end
    end
  end
end
