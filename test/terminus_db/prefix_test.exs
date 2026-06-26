defmodule TerminusDB.PrefixTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Error, Prefix}
  import TerminusDB.Test.Helpers

  defp db_config(adapter) do
    Config.with_database(
      Config.new(endpoint: "http://localhost:6363", user: "admin", key: "root", adapter: adapter),
      "mydb"
    )
  end

  describe "get/2" do
    test "GETs prefix/:org/:db/:repo/branch/:branch/:name and returns URI" do
      test = self()

      adapter =
        capture(
          test,
          Req.Response.new(status: 200, body: %{"api:prefix_uri" => "http://example.org/"})
        )

      assert {:ok, "http://example.org/"} = Prefix.get(db_config(adapter), "ex")
      req = last_request()
      assert req.method == :get
      assert req.url.path == "/api/prefix/admin/mydb/local/branch/main/ex"
    end

    test "get! returns the prefix URI or raises" do
      adapter = fn req ->
        {req, Req.Response.new(status: 200, body: %{"api:prefix_uri" => "http://example.org/"})}
      end

      assert Prefix.get!(db_config(adapter), "ex") == "http://example.org/"
    end

    test "get! raises on error" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end
      assert_raise Error, fn -> Prefix.get!(db_config(adapter), "missing") end
    end
  end

  describe "add/3" do
    test "POSTs prefix with URI body" do
      test = self()
      adapter = capture(test, ok(%{"api:status" => "api:success"}))

      assert {:ok, resp} = Prefix.add(db_config(adapter), "ex", "http://example.org/")
      assert resp["api:status"] == "api:success"
      req = last_request()
      assert req.method == :post
      assert {:ok, body} = Jason.decode(req.body)
      assert body["uri"] == "http://example.org/"
    end

    test "add! returns response or raises" do
      adapter = fn req -> {req, ok(%{"api:status" => "api:success"})} end

      assert Prefix.add!(db_config(adapter), "ex", "http://example.org/")["api:status"] ==
               "api:success"
    end

    test "add! raises on error" do
      adapter = fn req -> {req, resp(400, %{"api:message" => "exists"})} end
      assert_raise Error, fn -> Prefix.add!(db_config(adapter), "ex", "http://example.org/") end
    end
  end

  describe "update/3" do
    test "PUTs prefix with URI body" do
      test = self()
      adapter = capture(test, ok(%{"api:status" => "api:success"}))

      assert {:ok, resp} = Prefix.update(db_config(adapter), "ex", "http://example.com/")
      assert resp["api:status"] == "api:success"
      req = last_request()
      assert req.method == :put
    end

    test "update! returns response or raises" do
      adapter = fn req -> {req, ok(%{"api:status" => "api:success"})} end

      assert Prefix.update!(db_config(adapter), "ex", "http://example.com/")["api:status"] ==
               "api:success"
    end

    test "update! raises on error" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end
      assert_raise Error, fn -> Prefix.update!(db_config(adapter), "missing", "http://x/") end
    end
  end

  describe "upsert/3" do
    test "PUTs with create=true param" do
      test = self()
      adapter = capture(test, ok(%{"api:status" => "api:success"}))

      assert {:ok, resp} = Prefix.upsert(db_config(adapter), "ex", "http://example.org/")
      assert resp["api:status"] == "api:success"
      req = last_request()
      assert req.method == :put
      assert req.url.query =~ "create=true"
    end

    test "upsert! returns response or raises" do
      adapter = fn req -> {req, ok(%{"api:status" => "api:success"})} end

      assert Prefix.upsert!(db_config(adapter), "ex", "http://example.org/")["api:status"] ==
               "api:success"
    end
  end

  describe "delete/2" do
    test "DELETEs prefix" do
      test = self()
      adapter = capture(test, ok(%{"api:status" => "api:success"}))

      assert {:ok, resp} = Prefix.delete(db_config(adapter), "ex")
      assert resp["api:status"] == "api:success"
      req = last_request()
      assert req.method == :delete
    end

    test "delete! returns response or raises" do
      adapter = fn req -> {req, ok(%{"api:status" => "api:success"})} end
      assert Prefix.delete!(db_config(adapter), "ex")["api:status"] == "api:success"
    end

    test "delete! raises on error" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end
      assert_raise Error, fn -> Prefix.delete!(db_config(adapter), "missing") end
    end
  end

  describe "all/2" do
    test "GETs prefixes/:org/:db and returns all prefixes" do
      test = self()

      adapter =
        capture(
          test,
          Req.Response.new(
            status: 200,
            body: %{"@base" => "terminusdb:///data/", "@schema" => "terminusdb:///schema#"}
          )
        )

      assert {:ok, prefixes} = Prefix.all(db_config(adapter))
      assert prefixes["@schema"] == "terminusdb:///schema#"
      req = last_request()
      assert req.method == :get
      assert req.url.path == "/api/prefixes/admin/mydb"
    end

    test "all! returns all prefixes or raises" do
      adapter = fn req ->
        {req,
         Req.Response.new(
           status: 200,
           body: %{"@base" => "terminusdb:///data/", "@schema" => "terminusdb:///schema#"}
         )}
      end

      assert Prefix.all!(db_config(adapter))["@base"] == "terminusdb:///data/"
    end

    test "all! raises on error" do
      adapter = fn req -> {req, resp(500, %{"api:message" => "fail"})} end
      assert_raise Error, fn -> Prefix.all!(db_config(adapter)) end
    end
  end

  describe "error handling" do
    test "returns {:error, _} when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)
      assert {:error, _} = Prefix.get(config, "ex")
    end

    test "all returns {:error, _} when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)
      assert {:error, _} = Prefix.all(config)
    end

    test "honors :organization override" do
      test = self()

      adapter =
        capture(test, Req.Response.new(status: 200, body: %{"api:prefix_uri" => "http://x/"}))

      Prefix.get(db_config(adapter), "ex", organization: "acme")
      req = last_request()
      assert req.url.path == "/api/prefix/acme/mydb/local/branch/main/ex"
    end
  end
end
