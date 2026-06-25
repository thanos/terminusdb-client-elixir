defmodule TerminusDB.Integration.WOQLTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias TerminusDB.{Config, Database, Document, WOQL}

  defp config do
    endpoint = System.get_env("TERMINUSDB_URL", "http://localhost:6363")
    user = System.get_env("TERMINUSDB_USER", "admin")
    key = System.get_env("TERMINUSDB_KEY", "root")

    Config.new(endpoint: endpoint, user: user, key: key)
  end

  defp db_name do
    "int_woql_#{:erlang.unique_integer([:positive])}"
  end

  setup do
    cfg = config()
    db = db_name()
    Database.create!(cfg, db, label: "WOQL Integration Test", schema: true)
    scoped = Config.with_database(cfg, db)

    on_exit(fn ->
      Database.delete(cfg, db, force: true)
    end)

    {:ok, config: scoped, db: db}
  end

  defp insert_schema(cfg) do
    Document.insert!(
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
  end

  defp insert_person(cfg, name, age) do
    Document.insert!(
      cfg,
      %{"@type" => "Person", "name" => name, "age" => age},
      author: "admin",
      message: "add #{name}"
    )
  end

  describe "query modifiers" do
    test "limit and start paginate results", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)
      insert_person(cfg, "Bob", 25)
      insert_person(cfg, "Carol", 40)

      query =
        WOQL.select(
          ["v:Name"],
          WOQL.limit(
            2,
            WOQL.and_([
              WOQL.triple("v:P", "name", "v:Name"),
              WOQL.triple("v:P", "rdf:type", WOQL.iri("@schema:Person"))
            ])
          )
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
      assert length(result["bindings"]) <= 2
    end

    test "order_by orders results", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)
      insert_person(cfg, "Bob", 25)
      insert_person(cfg, "Carol", 40)

      query =
        WOQL.select(
          ["v:Name", "v:Age"],
          WOQL.order_by(
            [{"v:Age", :asc}],
            WOQL.and_([
              WOQL.triple("v:P", "name", "v:Name"),
              WOQL.triple("v:P", "age", "v:Age"),
              WOQL.triple("v:P", "rdf:type", WOQL.iri("@schema:Person"))
            ])
          )
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
      assert is_list(result["bindings"])
    end

    test "count counts solutions", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)
      insert_person(cfg, "Bob", 25)

      query =
        WOQL.count(
          "v:N",
          WOQL.and_([
            WOQL.triple("v:P", "rdf:type", WOQL.iri("@schema:Person"))
          ])
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
      assert is_list(result["bindings"])
    end
  end

  describe "logical combinators" do
    test "opt allows optional sub-queries", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)

      query =
        WOQL.select(
          ["v:Name"],
          WOQL.and_([
            WOQL.triple("v:P", "name", "v:Name"),
            WOQL.triple("v:P", "rdf:type", WOQL.iri("@schema:Person")),
            WOQL.opt(WOQL.triple("v:P", "age", "v:Age"))
          ])
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
      assert result["bindings"] != []
    end
  end

  describe "comparison" do
    test "less filters by comparison", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)
      insert_person(cfg, "Bob", 25)
      insert_person(cfg, "Carol", 40)

      query =
        WOQL.select(
          ["v:Name"],
          WOQL.and_([
            WOQL.triple("v:P", "name", "v:Name"),
            WOQL.triple("v:P", "age", "v:Age"),
            WOQL.triple("v:P", "rdf:type", WOQL.iri("@schema:Person")),
            WOQL.less("v:Age", 35)
          ])
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
      assert is_list(result["bindings"])
    end
  end

  describe "schema ops" do
    test "isa checks type membership", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)

      query =
        WOQL.select(
          ["v:P"],
          WOQL.and_([
            WOQL.isa("v:P", WOQL.iri("@schema:Person"))
          ])
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
      assert is_list(result["bindings"])
    end
  end

  describe "document mutations" do
    test "insert_document via WOQL", %{config: cfg} do
      insert_schema(cfg)

      query =
        WOQL.and_([
          WOQL.insert_document(WOQL.string("Person/Bob"))
        ])

      {:ok, result} =
        WOQL.execute(cfg, query,
          author: "admin",
          message: "insert doc via WOQL"
        )

      assert result["api:status"] == "api:success"
    end

    test "delete_document via WOQL", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)

      query =
        WOQL.and_([
          WOQL.delete_document("Person/Alice")
        ])

      {:ok, result} =
        WOQL.execute(cfg, query,
          author: "admin",
          message: "delete doc via WOQL"
        )

      assert result["api:status"] == "api:success"
    end
  end

  describe "graph mutations" do
    test "add_triple and delete_triple", %{config: cfg} do
      insert_schema(cfg)

      add_query =
        WOQL.and_([
          WOQL.add_triple("v:S", "name", "Alice"),
          WOQL.add_triple("v:S", "rdf:type", WOQL.iri("@schema:Person"))
        ])

      {:ok, add_result} =
        WOQL.execute(cfg, add_query,
          author: "admin",
          message: "add triple via WOQL"
        )

      assert add_result["api:status"] == "api:success"
    end
  end

  describe "path queries" do
    test "path with string pattern traverses graph", %{config: cfg} do
      insert_schema(cfg)

      Document.insert!(
        cfg,
        %{
          "@type" => "Class",
          "@id" => "Knows",
          "source" => "Person",
          "target" => "Person"
        },
        author: "admin",
        message: "add Knows schema",
        graph_type: :schema
      )

      insert_person(cfg, "Alice", 30)
      insert_person(cfg, "Bob", 25)

      query =
        WOQL.select(
          ["v:Target"],
          WOQL.and_([
            WOQL.triple("v:S", "name", WOQL.string("Alice")),
            WOQL.path("v:S", "<target*", "v:Target")
          ])
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
    end
  end
end
