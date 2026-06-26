defmodule TerminusDB.CommitTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Commit, Config, Error}
  import TerminusDB.Test.Helpers

  defp db_config(adapter) do
    Config.with_database(Config.new(endpoint: "http://localhost:6363", adapter: adapter), "mydb")
  end

  describe "log/2" do
    test "GETs log/:org/:db/:repo/branch/:branch" do
      test = self()

      log = [
        %{
          "commit" => "c1",
          "author" => "admin",
          "message" => "init",
          "timestamp" => "2026-06-24T10:00:00Z"
        }
      ]

      adapter = capture(test, Req.Response.new(status: 200, body: log))

      assert {:ok, ^log} = Commit.log(db_config(adapter))
      req = last_request()
      assert req.method == :get
      assert req.url.path == "/api/log/admin/mydb/local/branch/main"
    end

    test "passes :start, :limit, and :branch options" do
      test = self()
      adapter = capture(test, ok([]))

      Commit.log(db_config(adapter), start: "commit/abc", limit: 5, branch: "feature")
      req = last_request()
      assert req.url.path == "/api/log/admin/mydb/local/branch/feature"
      assert req.url.query =~ "start=commit%2Fabc"
      assert req.url.query =~ "limit=5"
    end

    test "returns an :api error on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end
      assert {:error, %Error{reason: :api}} = Commit.log(db_config(adapter))
    end
  end

  describe "log!/2" do
    test "returns the log on success" do
      adapter = fn req -> {req, ok([%{"commit" => "c1"}])} end
      assert Commit.log!(db_config(adapter)) == [%{"commit" => "c1"}]
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end
      assert_raise Error, fn -> Commit.log!(db_config(adapter)) end
    end
  end

  describe "history/2" do
    test "GETs history/:org/:db/:repo/branch/:branch" do
      test = self()
      adapter = capture(test, ok([%{"commit" => "c1"}]))

      assert {:ok, _} = Commit.history(db_config(adapter))
      req = last_request()
      assert req.method == :get
      assert req.url.path == "/api/log/admin/mydb/local/branch/main"
    end

    test "honors :organization override" do
      test = self()
      adapter = capture(test, ok([]))

      Commit.history(db_config(adapter), organization: "acme")
      req = last_request()
      assert req.url.path == "/api/log/acme/mydb/local/branch/main"
    end
  end

  describe "history!/2" do
    test "returns the history on success" do
      adapter = fn req -> {req, ok([%{"commit" => "c1"}])} end
      assert Commit.history!(db_config(adapter)) == [%{"commit" => "c1"}]
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end
      assert_raise Error, fn -> Commit.history!(db_config(adapter)) end
    end
  end

  describe "get/3" do
    test "GETs history/.../:commit_id" do
      test = self()
      adapter = capture(test, ok(%{"@id" => "commit/abc", "author" => "admin"}))

      assert {:ok, commit} = Commit.get(db_config(adapter), "commit/abc")
      req = last_request()
      assert req.method == :get
      assert req.url.path == "/api/history/admin/mydb/local/branch/main/commit/abc"
      assert commit["author"] == "admin"
    end

    test "raises when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)
      assert_raise Error, fn -> Commit.get(config, "commit/abc") end
    end
  end

  describe "get!/3" do
    test "returns the commit on success" do
      adapter = fn req -> {req, ok(%{"@id" => "commit/abc"})} end
      assert Commit.get!(db_config(adapter), "commit/abc") == %{"@id" => "commit/abc"}
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end
      assert_raise Error, fn -> Commit.get!(db_config(adapter), "commit/missing") end
    end
  end

  describe "document_history/3" do
    test "GETs history/:org/:db with id param" do
      test = self()

      history = [
        %{"author" => "admin", "identifier" => "abc", "message" => "Created"}
      ]

      adapter = capture(test, Req.Response.new(status: 200, body: history))

      assert {:ok, ^history} =
               Commit.document_history(db_config(adapter), id: "Person/Alice", count: 5)

      req = last_request()
      assert req.method == :get
      assert req.url.path == "/api/history/admin/mydb"
      assert req.url.query =~ "id=Person"
      assert req.url.query =~ "count=5"
    end

    test "includes created and updated flags when provided" do
      test = self()
      adapter = capture(test, ok([]))

      Commit.document_history(db_config(adapter),
        id: "Person/Alice",
        created: true,
        updated: false
      )

      req = last_request()
      assert req.url.query =~ "created=true"
      assert req.url.query =~ "updated=false"
    end

    test "document_history! returns list or raises" do
      adapter = fn req -> {req, Req.Response.new(status: 200, body: [%{"author" => "admin"}])} end

      assert Commit.document_history!(db_config(adapter), id: "Person/Alice") == [
               %{"author" => "admin"}
             ]
    end

    test "document_history! raises on error" do
      adapter = fn req -> {req, resp(500, %{"api:message" => "fail"})} end

      assert_raise Error, fn ->
        Commit.document_history!(db_config(adapter), id: "Person/Alice")
      end
    end

    test "raises when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)
      assert_raise Error, fn -> Commit.document_history(config, id: "Person/Alice") end
    end

    test "raises KeyError when :id is missing" do
      adapter = fn req -> {req, ok([])} end
      assert_raise KeyError, fn -> Commit.document_history(db_config(adapter), count: 5) end
    end
  end
end
