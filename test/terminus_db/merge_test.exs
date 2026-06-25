defmodule TerminusDB.MergeTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Error, Merge}
  import TerminusDB.Test.Helpers

  defp db_config(adapter) do
    Config.with_database(Config.new(endpoint: "http://localhost:6363", adapter: adapter), "mydb")
  end

  describe "merge/2" do
    test "POSTs to rebase/:org/:db/:repo/branch/:target with source" do
      test = self()
      adapter = capture(test, ok(%{"api:status" => "api:success"}))

      assert {:ok, result} =
               Merge.merge(db_config(adapter),
                 source_branch: "feature",
                 target_branch: "main"
               )

      req = last_request()
      assert req.method == :post
      assert req.url.path == "/api/rebase/admin/mydb/local/branch/main"

      assert {:ok, body} = Jason.decode(req.body)
      assert body["rebase_from"] == "admin/mydb/local/branch/feature"
      assert result["api:status"] == "api:success"
    end

    test "includes :author and :message when provided" do
      test = self()
      adapter = capture(test, ok(%{}))

      Merge.merge(db_config(adapter),
        source_branch: "feature",
        target_branch: "main",
        author: "admin",
        message: "merge feature"
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["author"] == "admin"
      assert body["message"] == "merge feature"
    end

    test "honors :organization override" do
      test = self()
      adapter = capture(test, ok(%{}))

      Merge.merge(db_config(adapter),
        source_branch: "feature",
        target_branch: "main",
        organization: "acme"
      )

      req = last_request()
      assert req.url.path == "/api/rebase/acme/mydb/local/branch/main"
    end

    test "raises KeyError when :source_branch is missing" do
      adapter = fn req -> {req, ok(%{})} end

      assert_raise KeyError, fn ->
        Merge.merge(db_config(adapter), target_branch: "main")
      end
    end

    test "raises when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)

      assert_raise Error, fn ->
        Merge.merge(config, source_branch: "feature")
      end
    end
  end

  describe "merge!/2" do
    test "returns the result on success" do
      adapter = fn req -> {req, ok(%{"api:status" => "api:success"})} end

      assert Merge.merge!(db_config(adapter), source_branch: "feature", target_branch: "main") ==
               %{"api:status" => "api:success"}
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(409, %{"@type" => "api:Conflict"})} end

      assert_raise Error, fn ->
        Merge.merge!(db_config(adapter), source_branch: "feature", target_branch: "main")
      end
    end
  end
end
