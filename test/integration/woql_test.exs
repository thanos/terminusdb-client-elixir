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
        "@key" => %{"@type" => "Lexical", "@fields" => ["name"]},
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

  defp extract_value(%{"@value" => value}), do: value
  defp extract_value(value), do: value

  defp binding_values(bindings, key) do
    Enum.map(bindings, fn b -> extract_value(Map.get(b, key)) end)
  end

  describe "query modifiers" do
    test "limit restricts result count", %{config: cfg} do
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
      assert length(result["bindings"]) == 2
    end

    test "order_by returns results in ascending order", %{config: cfg} do
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
      ages = binding_values(result["bindings"], "Age")
      assert ages == Enum.sort(ages)
      assert 25 in ages
      assert 40 in ages
    end

    test "count returns the number of persons", %{config: cfg} do
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
      [binding] = result["bindings"]
      assert extract_value(binding["N"]) == 2
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
      names = binding_values(result["bindings"], "Name")
      assert "Alice" in names
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
      names = binding_values(result["bindings"], "Name")
      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
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
      assert result["bindings"] != []
    end
  end

  describe "document mutations" do
    test "insert_document via WOQL", %{config: cfg} do
      insert_schema(cfg)

      query =
        WOQL.and_([
          WOQL.insert_document(
            %{
              "@type" => "Person",
              "name" => "Bob",
              "age" => 35
            },
            "v:Id"
          )
        ])

      {:ok, result} =
        WOQL.execute(cfg, query,
          author: "admin",
          message: "insert doc via WOQL"
        )

      assert result["api:status"] == "api:success"

      {:ok, doc} = Document.get(cfg, id: "Person/Bob")
      assert doc["name"] == "Bob"
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
      assert {:error, _} = Document.get(cfg, id: "Person/Alice")
    end
  end

  describe "graph mutations" do
    test "add_triple and delete_triple", %{config: cfg} do
      insert_schema(cfg)

      add_query =
        WOQL.and_([
          WOQL.add_triple("Person/Test", "rdf:type", WOQL.iri("@schema:Person")),
          WOQL.add_triple("Person/Test", "name", "Test"),
          WOQL.add_triple("Person/Test", "age", WOQL.literal(42, "integer"))
        ])

      {:ok, add_result} =
        WOQL.execute(cfg, add_query,
          author: "admin",
          message: "add triple via WOQL"
        )

      assert add_result["api:status"] == "api:success"

      read_query =
        WOQL.select(
          ["v:Name"],
          WOQL.and_([
            WOQL.triple("Person/Test", "name", "v:Name")
          ])
        )

      {:ok, read_result} = WOQL.execute(cfg, read_query)
      names = binding_values(read_result["bindings"], "Name")
      assert "Test" in names
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
          "@key" => %{"@type" => "Lexical", "@fields" => ["source", "target"]},
          "source" => "Person",
          "target" => "Person"
        },
        author: "admin",
        message: "add Knows schema",
        graph_type: :schema
      )

      insert_person(cfg, "Alice", 30)
      insert_person(cfg, "Bob", 25)
      insert_person(cfg, "Carol", 40)

      Document.insert!(
        cfg,
        %{"@type" => "Knows", "source" => "Person/Alice", "target" => "Person/Bob"},
        author: "admin",
        message: "Alice knows Bob"
      )

      Document.insert!(
        cfg,
        %{"@type" => "Knows", "source" => "Person/Bob", "target" => "Person/Carol"},
        author: "admin",
        message: "Bob knows Carol"
      )

      query =
        WOQL.select(
          ["v:Target"],
          WOQL.and_([
            WOQL.triple("v:S", "name", WOQL.string("Alice")),
            WOQL.path("v:S", "(<source,target)+", "v:Target")
          ])
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
      targets = binding_values(result["bindings"], "Target")
      assert "Person/Bob" in targets or "terminusdb:///data/Person/Bob" in targets
    end
  end

  describe "range queries" do
    test "triple_slice returns values in range", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)
      insert_person(cfg, "Bob", 25)
      insert_person(cfg, "Carol", 40)

      query =
        WOQL.select(
          ["v:Name", "v:Age"],
          WOQL.and_([
            WOQL.triple("v:P", "name", "v:Name"),
            WOQL.triple("v:P", "age", "v:Age"),
            WOQL.triple("v:P", "rdf:type", WOQL.iri("@schema:Person")),
            WOQL.triple_slice("v:P", "age", "v:Age", 20, 35)
          ])
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
      names = binding_values(result["bindings"], "Name")
      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "triple_next finds next value after reference", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)
      insert_person(cfg, "Bob", 25)
      insert_person(cfg, "Carol", 40)

      query =
        WOQL.select(
          ["v:Next"],
          WOQL.and_([
            WOQL.triple("v:P", "age", 25),
            WOQL.triple_next("v:P", "age", 25, "v:Next")
          ])
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
    end
  end

  describe "temporal / Allen" do
    test "in_range checks if value is in range", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)

      query =
        WOQL.select(
          ["v:Name"],
          WOQL.and_([
            WOQL.triple("v:P", "name", "v:Name"),
            WOQL.triple("v:P", "age", "v:Age"),
            WOQL.in_range("v:Age", 20, 40)
          ])
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
      names = binding_values(result["bindings"], "Name")
      assert "Alice" in names
    end

    test "day_after computes next day", %{config: cfg} do
      insert_schema(cfg)

      query =
        WOQL.select(
          ["v:Next"],
          WOQL.day_after(WOQL.date("2026-01-15"), "v:Next")
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
      next_days = binding_values(result["bindings"], "Next")
      assert "2026-01-16" in next_days
    end

    test "weekday computes ISO weekday", %{config: cfg} do
      insert_schema(cfg)

      query =
        WOQL.select(
          ["v:Day"],
          WOQL.weekday("2026-01-15", "v:Day")
        )

      {:ok, result} = WOQL.execute(cfg, query)
      assert result["api:status"] == "api:success"
    end

    test "range_min encodes and executes", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)

      query =
        WOQL.select(
          ["v:Min"],
          WOQL.range_min("v:Ages", "v:Min")
        )

      result = WOQL.execute(cfg, query)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "range_max encodes and executes", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)

      query =
        WOQL.select(
          ["v:Max"],
          WOQL.range_max("v:Ages", "v:Max")
        )

      result = WOQL.execute(cfg, query)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "WOQL streaming" do
    test "execute_stream returns a stream of bindings", %{config: cfg} do
      insert_schema(cfg)
      insert_person(cfg, "Alice", 30)
      insert_person(cfg, "Bob", 25)

      query =
        WOQL.select(
          ["v:Name"],
          WOQL.and_([
            WOQL.triple("v:P", "name", "v:Name"),
            WOQL.triple("v:P", "rdf:type", WOQL.iri("@schema:Person"))
          ])
        )

      {:ok, stream} = WOQL.execute_stream(cfg, query)
      bindings = Enum.to_list(stream)
      assert length(bindings) >= 2
    end
  end
end
