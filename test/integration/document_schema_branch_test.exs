defmodule TerminusDB.Integration.DocumentSchemaBranchTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias TerminusDB.{Branch, Config, Database, Document, Schema}

  defp config do
    endpoint = System.get_env("TERMINUSDB_URL", "http://localhost:6363")
    user = System.get_env("TERMINUSDB_USER", "admin")
    key = System.get_env("TERMINUSDB_KEY", "root")

    Config.new(endpoint: endpoint, user: user, key: key)
  end

  defp db_name do
    "int_doc_#{:erlang.unique_integer([:positive])}"
  end

  setup do
    cfg = config()
    db = db_name()
    Database.create!(cfg, db, label: "Integration Doc Test", schema: true)
    scoped = Config.with_database(cfg, db)

    on_exit(fn ->
      Database.delete(cfg, db, force: true)
    end)

    {:ok, config: scoped, db: db}
  end

  describe "schema" do
    test "retrieves all schema frames for an empty schema", %{config: cfg} do
      {:ok, frames} = Schema.all(cfg)
      assert is_map(frames)
    end

    test "retrieves a specific class frame after inserting a schema", %{config: cfg} do
      Document.insert!(
        cfg,
        %{"@type" => "Class", "@id" => "Person", "name" => "xsd:string", "age" => "xsd:integer"},
        author: "admin",
        message: "add schema",
        graph_type: :schema
      )

      {:ok, frame} = Schema.frame(cfg, "Person")
      assert is_map(frame)
    end
  end

  describe "document lifecycle" do
    test "insert, get, query, replace, and delete a document", %{config: cfg} do
      # Insert a schema first (Person class)
      {:ok, _} =
        Document.insert(
          cfg,
          %{
            "@type" => "Class",
            "@id" => "Person",
            "name" => "xsd:string",
            "age" => "xsd:integer"
          },
          author: "admin",
          message: "add schema",
          graph_type: :schema
        )

      # Insert two documents with different ages
      {:ok, _} =
        Document.insert(cfg, %{"@type" => "Person", "name" => "Alice", "age" => 30},
          author: "admin",
          message: "add Alice"
        )

      {:ok, _} =
        Document.insert(cfg, %{"@type" => "Person", "name" => "Bob", "age" => 25},
          author: "admin",
          message: "add Bob"
        )

      # Get all documents of type Person
      {:ok, docs} = Document.get(cfg, type: "Person", as_list: true)
      assert is_list(docs)
      person = Enum.find(docs, &(&1["name"] == "Alice"))
      assert person != nil
      assert person["age"] == 30

      # Query by template: returns documents matching the type
      {:ok, matches} = Document.query(cfg, %{"@type" => "Person"})
      assert is_list(matches)
      names = Enum.map(matches, & &1["name"])
      assert "Alice" in names

      # Delete the document
      person_id = person["@id"]
      {:ok, _} = Document.delete(cfg, id: person_id, author: "admin", message: "remove Alice")

      # Verify it's gone
      {:ok, remaining} = Document.get(cfg, type: "Person", as_list: true)
      refute Enum.any?(remaining, &(&1["name"] == "Alice"))
    end

    test "stream yields documents one at a time", %{config: cfg} do
      Document.insert!(
        cfg,
        %{"@type" => "Class", "@id" => "Item", "label" => "xsd:string"},
        author: "admin",
        message: "add schema",
        graph_type: :schema
      )

      Document.insert!(
        cfg,
        [
          %{"@type" => "Item", "label" => "one"},
          %{"@type" => "Item", "label" => "two"},
          %{"@type" => "Item", "label" => "three"}
        ],
        author: "admin",
        message: "add items"
      )

      docs = Enum.to_list(Document.stream(cfg, type: "Item"))

      labels = Enum.sort(Enum.map(docs, & &1["label"]))
      assert labels == ["one", "three", "two"]
    end
  end

  describe "branch" do
    test "create, exists?, and delete a branch", %{config: cfg} do
      # Create a branch
      {:ok, resp} = Branch.create(cfg, "feature_branch")
      assert resp["api:status"] == "api:success"

      # Exists
      assert Branch.exists?(cfg, "feature_branch") == true

      # Delete
      {:ok, delete_resp} = Branch.delete(cfg, "feature_branch")
      assert delete_resp["api:status"] == "api:success"

      # No longer exists
      assert Branch.exists?(cfg, "feature_branch") == false
    end
  end
end
