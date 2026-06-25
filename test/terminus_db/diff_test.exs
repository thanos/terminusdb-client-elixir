defmodule TerminusDB.DiffTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Diff, Error}
  import TerminusDB.Test.Helpers

  defp db_config(adapter) do
    Config.with_database(Config.new(endpoint: "http://localhost:6363", adapter: adapter), "mydb")
  end

  describe "compare/2" do
    test "POSTs to diff/:org/:db with before and after" do
      test = self()

      patch = %{"name" => %{"@op" => "ValueSwap", "@before" => "Alice", "@after" => "Alicia"}}

      adapter = capture(test, Req.Response.new(status: 200, body: patch))

      assert {:ok, ^patch} =
               Diff.compare(db_config(adapter),
                 before: %{"@id" => "Person/Alice", "name" => "Alice"},
                 after: %{"@id" => "Person/Alice", "name" => "Alicia"}
               )

      req = last_request()
      assert req.method == :post
      assert req.url.path == "/api/diff/admin/mydb"

      assert {:ok, body} = Jason.decode(req.body)
      assert body["before"]["name"] == "Alice"
      assert body["after"]["name"] == "Alicia"
    end

    test "includes :keep when provided" do
      test = self()
      adapter = capture(test, ok(%{}))

      Diff.compare(db_config(adapter),
        before: %{"name" => "Alice"},
        after: %{"name" => "Alicia"},
        keep: %{"@id" => true}
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["keep"] == %{"@id" => true}
    end

    test "compares branch refs as strings" do
      test = self()
      adapter = capture(test, ok(%{}))

      Diff.compare(db_config(adapter),
        before: "admin/mydb/local/branch/main",
        after: "admin/mydb/local/branch/feature"
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["before"] == "admin/mydb/local/branch/main"
      assert body["after"] == "admin/mydb/local/branch/feature"
    end

    test "honors :organization override" do
      test = self()
      adapter = capture(test, ok(%{}))

      Diff.compare(db_config(adapter),
        before: %{},
        after: %{},
        organization: "acme"
      )

      req = last_request()
      assert req.url.path == "/api/diff/acme/mydb"
    end

    test "raises KeyError when :before is missing" do
      adapter = fn req -> {req, ok(%{})} end

      assert_raise KeyError, fn ->
        Diff.compare(db_config(adapter), after: %{})
      end
    end

    test "raises when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)

      assert_raise Error, fn ->
        Diff.compare(config, before: %{}, after: %{})
      end
    end
  end

  describe "compare!/2" do
    test "returns the patch on success" do
      adapter = fn req -> {req, ok(%{"name" => %{"@op" => "ValueSwap"}})} end

      assert Diff.compare!(db_config(adapter),
               before: %{"name" => "Alice"},
               after: %{"name" => "Alicia"}
             ) == %{"name" => %{"@op" => "ValueSwap"}}
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end

      assert_raise Error, fn ->
        Diff.compare!(db_config(adapter), before: %{}, after: %{})
      end
    end
  end
end
