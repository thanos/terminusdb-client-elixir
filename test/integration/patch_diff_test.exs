defmodule TerminusDB.Integration.PatchDiffTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias TerminusDB.{Config, Database, Diff, Document, Patch}

  defp config do
    endpoint = System.get_env("TERMINUSDB_URL", "http://localhost:6363")
    user = System.get_env("TERMINUSDB_USER", "admin")
    key = System.get_env("TERMINUSDB_KEY", "root")

    Config.new(endpoint: endpoint, user: user, key: key)
  end

  setup do
    cfg = config()
    db = "int_patch_#{:erlang.unique_integer([:positive])}"
    Database.create!(cfg, db, label: "Patch Test", schema: true)
    scoped = Config.with_database(cfg, db)

    Document.insert!(
      scoped,
      %{
        "@type" => "Class",
        "@id" => "Person",
        "@key" => %{"@type" => "Lexical", "@fields" => ["name"]},
        "name" => "xsd:string",
        "age" => "xsd:integer"
      },
      author: "admin",
      message: "add schema",
      graph_type: :schema
    )

    Document.insert!(
      scoped,
      %{"@type" => "Person", "name" => "Alice", "age" => 30},
      author: "admin",
      message: "add Alice"
    )

    on_exit(fn ->
      Database.delete(cfg, db, force: true)
    end)

    {:ok, config: scoped}
  end

  describe "diff_object" do
    test "diffs two documents and returns Patch", %{config: cfg} do
      assert {:ok, %Patch{} = patch} =
               Diff.diff_object(cfg,
                 before: %{"@id" => "Person/Alice", "name" => "Alice", "age" => 30},
                 after: %{"@id" => "Person/Alice", "name" => "Alicia", "age" => 31}
               )

      assert is_map(patch.content)
    end
  end

  describe "patch" do
    test "applies a patch to a before object", %{config: cfg} do
      {:ok, %Patch{} = patch} =
        Diff.diff_object(cfg,
          before: %{"@id" => "Person/Alice", "name" => "Alice"},
          after: %{"@id" => "Person/Alice", "name" => "Alicia"}
        )

      assert {:ok, result} =
               Diff.patch(cfg,
                 before: %{"@id" => "Person/Alice", "name" => "Alice"},
                 patch: patch.content
               )

      assert is_map(result)
    end
  end

  describe "Commit.document_history" do
    test "returns history for a document", %{config: cfg} do
      alias TerminusDB.Commit
      assert {:ok, history} = Commit.document_history(cfg, id: "Person/Alice", count: 10)
      assert is_list(history)
      assert history != []
    end
  end

  describe "Branch.squash and reset" do
    test "squash compresses branch history", %{config: cfg} do
      alias TerminusDB.Branch
      assert {:ok, _} = Branch.squash(cfg, author: "admin", message: "squash")
    end
  end

  describe "Database.optimize" do
    test "optimizes a branch", %{config: cfg} do
      alias TerminusDB.Database
      assert {:ok, _} = Database.optimize(cfg, "admin/#{cfg.database}/local/branch/main")
    end
  end
end
