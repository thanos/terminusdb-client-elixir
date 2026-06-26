defmodule TerminusDB.DiffTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Diff, Error, Patch}
  import TerminusDB.Test.Helpers

  defp db_config(adapter) do
    Config.with_database(Config.new(endpoint: "http://localhost:6363", adapter: adapter), "mydb")
  end

  defp diff_resource_config(adapter) do
    Config.with_database(
      Config.new(
        endpoint: "http://localhost:6363",
        user: "admin",
        key: "root",
        adapter: adapter
      ),
      "mydb"
    )
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

  describe "diff_object/2" do
    test "returns a Patch struct on success" do
      test = self()
      patch_body = %{"name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}}
      adapter = capture(test, Req.Response.new(status: 200, body: patch_body))

      assert {:ok, %Patch{} = patch} =
               Diff.diff_object(diff_resource_config(adapter),
                 before: %{"@id" => "Person/1", "name" => "old"},
                 after: %{"@id" => "Person/1", "name" => "new"}
               )

      assert patch.content["name"]["@after"] == "new"
    end

    test "POSTs to diff resource path" do
      test = self()
      adapter = capture(test, ok(%{}))

      Diff.diff_object(diff_resource_config(adapter),
        before: %{"name" => "old"},
        after: %{"name" => "new"}
      )

      req = last_request()
      assert req.method == :post
      assert req.url.path == "/api/diff/admin/mydb/local/branch/main"
    end

    test "includes keep when provided" do
      test = self()
      adapter = capture(test, ok(%{}))

      Diff.diff_object(diff_resource_config(adapter),
        before: %{"name" => "old"},
        after: %{"name" => "new"},
        keep: %{"@id" => true}
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["keep"] == %{"@id" => true}
    end

    test "diff_object! returns Patch or raises" do
      adapter = fn req ->
        {req, Req.Response.new(status: 200, body: %{"name" => %{"@op" => "SwapValue"}})}
      end

      patch = Diff.diff_object!(diff_resource_config(adapter), before: %{}, after: %{})
      assert %Patch{} = patch
    end

    test "diff_object! raises on error" do
      adapter = fn req -> {req, resp(500, %{"api:message" => "error"})} end

      assert_raise Error, fn ->
        Diff.diff_object!(diff_resource_config(adapter), before: %{}, after: %{})
      end
    end

    test "returns error on transport failure" do
      adapter = fn req ->
        {req, Req.Response.new(status: 404, body: %{"@type" => "api:NotFound"})}
      end

      assert {:error, _} =
               Diff.diff_object(diff_resource_config(adapter), before: %{}, after: %{})
    end
  end

  describe "diff_version/2" do
    test "returns a Patch struct" do
      adapter = fn req -> {req, Req.Response.new(status: 200, body: %{})} end

      assert {:ok, %Patch{} = patch} =
               Diff.diff_version(diff_resource_config(adapter),
                 before_version: "admin/mydb/local/branch/main",
                 after_version: "admin/mydb/local/branch/feature"
               )

      assert patch.content == %{}
    end

    test "POSTs with before_data_version and after_data_version" do
      test = self()
      adapter = capture(test, ok(%{}))

      Diff.diff_version(diff_resource_config(adapter),
        before_version: "admin/mydb/local/commit/abc",
        after_version: "admin/mydb/local/commit/def"
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["before_data_version"] == "admin/mydb/local/commit/abc"
      assert body["after_data_version"] == "admin/mydb/local/commit/def"
    end

    test "diff_version! returns Patch or raises" do
      adapter = fn req -> {req, Req.Response.new(status: 200, body: %{})} end

      assert %Patch{} =
               Diff.diff_version!(diff_resource_config(adapter),
                 before_version: "a",
                 after_version: "b"
               )
    end
  end

  describe "patch/2" do
    test "POSTs to /api/patch with before and patch" do
      test = self()
      adapter = capture(test, Req.Response.new(status: 200, body: %{"name" => "new"}))

      assert {:ok, result} =
               Diff.patch(diff_resource_config(adapter),
                 before: %{"name" => "old"},
                 patch: %{"name" => %{"@op" => "SwapValue", "@after" => "new"}}
               )

      assert result["name"] == "new"

      req = last_request()
      assert req.method == :post
      assert req.url.path == "/api/patch"
    end

    test "patch! returns result or raises" do
      adapter = fn req -> {req, Req.Response.new(status: 200, body: %{"name" => "new"})} end

      assert Diff.patch!(diff_resource_config(adapter), before: %{}, patch: %{}) == %{
               "name" => "new"
             }
    end

    test "patch! raises on error" do
      adapter = fn req -> {req, resp(400, %{"api:message" => "bad patch"})} end

      assert_raise Error, fn ->
        Diff.patch!(diff_resource_config(adapter), before: %{}, patch: %{})
      end
    end
  end

  describe "patch_resource/2" do
    test "POSTs to patch resource path" do
      test = self()
      adapter = capture(test, ok(%{"api:status" => "api:success"}))

      assert {:ok, resp} =
               Diff.patch_resource(diff_resource_config(adapter),
                 patch: %{"name" => %{"@op" => "SwapValue"}},
                 author: "admin",
                 message: "update"
               )

      assert resp["api:status"] == "api:success"

      req = last_request()
      assert req.method == :post
      assert req.url.path == "/api/patch/admin/mydb/local/branch/main"

      assert {:ok, body} = Jason.decode(req.body)
      assert body["author"] == "admin"
      assert body["message"] == "update"
    end

    test "patch_resource! returns result or raises" do
      adapter = fn req -> {req, ok(%{"api:status" => "api:success"})} end

      assert Diff.patch_resource!(diff_resource_config(adapter), patch: %{})["api:status"] ==
               "api:success"
    end

    test "includes match_final_state when provided" do
      test = self()
      adapter = capture(test, ok(%{}))

      Diff.patch_resource(diff_resource_config(adapter),
        patch: %{},
        match_final_state: true
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["match_final_state"] == true
    end
  end

  describe "apply/2" do
    test "POSTs to apply resource path" do
      test = self()
      adapter = capture(test, ok(%{"api:status" => "api:success"}))

      assert {:ok, resp} =
               Diff.apply(diff_resource_config(adapter),
                 before_version: "admin/mydb/local/commit/abc",
                 after_version: "admin/mydb/local/commit/def",
                 author: "admin",
                 message: "apply"
               )

      assert resp["api:status"] == "api:success"

      req = last_request()
      assert req.method == :post
      assert req.url.path == "/api/apply/admin/mydb/local/branch/main"

      assert {:ok, body} = Jason.decode(req.body)
      assert body["before_commit"] == "admin/mydb/local/commit/abc"
      assert body["after_commit"] == "admin/mydb/local/commit/def"
      assert body["commit_info"]["author"] == "admin"
    end

    test "apply! returns result or raises" do
      adapter = fn req -> {req, ok(%{"api:status" => "api:success"})} end

      assert Diff.apply!(diff_resource_config(adapter), before_version: "a", after_version: "b")[
               "api:status"
             ] == "api:success"
    end

    test "apply! raises on error" do
      adapter = fn req -> {req, resp(500, %{"api:message" => "fail"})} end

      assert_raise Error, fn ->
        Diff.apply!(diff_resource_config(adapter), before_version: "a", after_version: "b")
      end
    end
  end
end
