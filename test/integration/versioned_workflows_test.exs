defmodule TerminusDB.Integration.VersionedWorkflowsTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias TerminusDB.{Branch, Commit, Config, Database, Diff, Document, Merge, WOQL}

  defp config do
    endpoint = System.get_env("TERMINUSDB_URL", "http://localhost:6363")
    user = System.get_env("TERMINUSDB_USER", "admin")
    key = System.get_env("TERMINUSDB_KEY", "root")

    Config.new(endpoint: endpoint, user: user, key: key)
  end

  defp db_name do
    "int_vwf_#{:erlang.unique_integer([:positive])}"
  end

  setup do
    cfg = config()
    db = db_name()
    Database.create!(cfg, db, label: "Versioned Workflows Test", schema: true)
    scoped = Config.with_database(cfg, db)

    on_exit(fn ->
      Database.delete(cfg, db, force: true)
    end)

    {:ok, config: scoped, db: db}
  end

  describe "commit" do
    test "log and history return commits after a write", %{config: cfg} do
      # Insert a schema + document to create commits
      Document.insert!(
        cfg,
        %{"@type" => "Class", "@id" => "Item", "label" => "xsd:string"},
        author: "admin",
        message: "add schema",
        graph_type: :schema
      )

      Document.insert!(
        cfg,
        %{"@type" => "Item", "label" => "widget"},
        author: "admin",
        message: "add widget"
      )

      # Log should return at least one commit
      {:ok, log} = Commit.log(cfg)
      assert is_list(log)
      assert log != []

      # History should also return commits
      {:ok, history} = Commit.history(cfg)
      assert is_list(history)
      assert history != []
    end
  end

  describe "diff" do
    test "diff between two document values", %{config: cfg} do
      {:ok, patch} =
        Diff.compare(cfg,
          before: %{"@id" => "Item/1", "label" => "old"},
          after: %{"@id" => "Item/1", "label" => "new"}
        )

      assert is_map(patch)
    end
  end

  describe "merge" do
    test "create branch, diverge, then merge", %{config: cfg} do
      # Insert schema + initial document
      Document.insert!(
        cfg,
        %{"@type" => "Class", "@id" => "Thing", "name" => "xsd:string"},
        author: "admin",
        message: "add schema",
        graph_type: :schema
      )

      Document.insert!(
        cfg,
        %{"@type" => "Thing", "name" => "original"},
        author: "admin",
        message: "add thing"
      )

      # Create a feature branch
      {:ok, _} = Branch.create(cfg, "merge_test")

      feature_config = Config.with_branch(cfg, "merge_test")

      # Add a document on the feature branch
      Document.insert!(
        feature_config,
        %{"@type" => "Thing", "name" => "from-feature"},
        author: "admin",
        message: "add on feature"
      )

      # Merge feature into main
      {:ok, result} = Merge.merge(cfg, source_branch: "merge_test", target_branch: "main")
      assert result["api:status"] == "api:success"

      # The feature document should now be on main
      {:ok, docs} = Document.get(cfg, type: "Thing", as_list: true)
      names = Enum.map(docs, & &1["name"])
      assert "from-feature" in names

      # Cleanup
      {:ok, _} = Branch.delete(cfg, "merge_test")
    end
  end

  describe "woql" do
    test "execute a WOQL query and get bindings", %{config: cfg} do
      # Insert schema + document
      Document.insert!(
        cfg,
        %{"@type" => "Class", "@id" => "Gadget", "name" => "xsd:string"},
        author: "admin",
        message: "add schema",
        graph_type: :schema
      )

      Document.insert!(
        cfg,
        %{"@type" => "Gadget", "name" => "gizmo"},
        author: "admin",
        message: "add gizmo"
      )

      query =
        WOQL.select(
          ["v:Name"],
          WOQL.and_([
            WOQL.triple("v:G", "name", "v:Name"),
            WOQL.eq("v:Name", "gizmo")
          ])
        )

      {:ok, result} = WOQL.execute(cfg, query)

      assert result["api:status"] == "api:success"
      assert is_list(result["bindings"])
      [%{"Name" => name}] = result["bindings"]
      assert name == "gizmo" or name == %{"@type" => "xsd:string", "@value" => "gizmo"}
    end

    test "execute a WOQL query with a constant object node", %{config: cfg} do
      Document.insert!(
        cfg,
        %{"@type" => "Class", "@id" => "Widget", "name" => "xsd:string"},
        author: "admin",
        message: "add schema",
        graph_type: :schema
      )

      Document.insert!(
        cfg,
        %{"@type" => "Widget", "name" => "w1"},
        author: "admin",
        message: "add widget"
      )

      query =
        WOQL.select(
          ["v:W"],
          WOQL.triple("v:W", "rdf:type", WOQL.iri("@schema:Widget"))
        )

      {:ok, result} = WOQL.execute(cfg, query)

      assert result["api:status"] == "api:success"
      assert is_list(result["bindings"])
      assert result["bindings"] != []
    end

    test "execute a type_of query", %{config: cfg} do
      Document.insert!(
        cfg,
        %{"@type" => "Class", "@id" => "Doohickey", "name" => "xsd:string"},
        author: "admin",
        message: "add schema",
        graph_type: :schema
      )

      Document.insert!(
        cfg,
        %{"@type" => "Doohickey", "name" => "d1"},
        author: "admin",
        message: "add doohickey"
      )

      query = WOQL.type_of("v:D", "v:T")

      {:ok, result} = WOQL.execute(cfg, query)

      assert result["api:status"] == "api:success"
      assert is_list(result["bindings"])
    end

    test "execute a read_document query", %{config: cfg} do
      Document.insert!(
        cfg,
        %{"@type" => "Class", "@id" => "Gadget", "name" => "xsd:string"},
        author: "admin",
        message: "add schema",
        graph_type: :schema
      )

      {:ok, doc} =
        Document.insert(
          cfg,
          %{"@type" => "Gadget", "name" => "g1"},
          author: "admin",
          message: "add gadget"
        )

      doc_id = doc["@id"] || doc["iri"] || "Gadget/" <> Map.get(doc, "name", "g1")

      query = WOQL.read_document(doc_id, "v:Doc")

      {:ok, result} = WOQL.execute(cfg, query)

      assert result["api:status"] == "api:success"
      assert is_list(result["bindings"])
      assert result["bindings"] != []
    end
  end
end
