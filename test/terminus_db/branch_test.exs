defmodule TerminusDB.BranchTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Branch, Config, Error}
  import TerminusDB.Test.Helpers

  defp db_config(adapter) do
    Config.with_database(Config.new(endpoint: "http://localhost:6363", adapter: adapter), "mydb")
  end

  describe "create/3" do
    test "POSTs to branch/:org/:db/:repo/branch/:name with origin body" do
      test = self()

      adapter =
        capture(test, ok(%{"@type" => "api:BranchResponse", "api:status" => "api:success"}))

      assert {:ok, _} = Branch.create(db_config(adapter), "feature")
      req = last_request()
      assert req.method == :post
      assert req.url.path == "/api/branch/admin/mydb/local/branch/feature"

      assert {:ok, body} = Jason.decode(req.body)
      assert body["origin"] == "admin/mydb/local/branch/main"
    end

    test "honors :from option for the origin branch" do
      test = self()
      adapter = capture(test, ok())

      Branch.create(db_config(adapter), "dev", from: "main")
      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["origin"] == "admin/mydb/local/branch/main"
    end

    test "honors :organization and :repo overrides in both path and origin body" do
      test = self()
      adapter = capture(test, ok())

      Branch.create(db_config(adapter), "feature", organization: "acme", repo: "origin")
      req = last_request()
      assert req.url.path == "/api/branch/acme/mydb/origin/branch/feature"

      assert {:ok, body} = Jason.decode(req.body)
      assert body["origin"] == "acme/mydb/origin/branch/main"
    end

    test "raises when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)
      assert_raise Error, fn -> Branch.create(config, "feature") end
    end
  end

  describe "create!/3" do
    test "returns the response body on success" do
      adapter = fn req -> {req, ok(%{"@type" => "api:BranchResponse"})} end

      assert %{"@type" => "api:BranchResponse"} =
               Branch.create!(db_config(adapter), "feature")
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(400, %{"@type" => "api:bad"})} end
      assert_raise Error, fn -> Branch.create!(db_config(adapter), "feature") end
    end
  end

  describe "delete/3" do
    test "DELETEs branch/:org/:db/:repo/branch/:name" do
      test = self()
      adapter = capture(test, ok())

      assert {:ok, _} = Branch.delete(db_config(adapter), "feature")
      req = last_request()
      assert req.method == :delete
      assert req.url.path == "/api/branch/admin/mydb/local/branch/feature"
    end

    test "honors :organization and :repo overrides" do
      test = self()
      adapter = capture(test, ok())

      Branch.delete(db_config(adapter), "feature", organization: "acme", repo: "origin")
      req = last_request()
      assert req.url.path == "/api/branch/acme/mydb/origin/branch/feature"
    end
  end

  describe "delete!/3" do
    test "raises on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end
      assert_raise Error, fn -> Branch.delete!(db_config(adapter), "missing") end
    end
  end

  describe "exists?/3" do
    test "returns true on 200 and issues a HEAD" do
      test = self()

      adapter = fn req ->
        send(test, {:request, req})
        {req, Req.Response.new(status: 200, body: "")}
      end

      assert Branch.exists?(db_config(adapter), "feature") == true
      req = last_request()
      assert req.method == :head
      assert req.url.path == "/api/branch/admin/mydb/local/branch/feature"
    end

    test "returns false on 404" do
      adapter = fn req -> {req, Req.Response.new(status: 404, body: "")} end
      assert Branch.exists?(db_config(adapter), "missing") == false
    end

    test "raises on unexpected errors" do
      adapter = fn req -> {req, resp(401, %{"@type" => "api:Unauthorized"})} end
      assert_raise Error, fn -> Branch.exists?(db_config(adapter), "feature") end
    end
  end
end
