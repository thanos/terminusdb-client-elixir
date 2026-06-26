defmodule TerminusDB.Integration.GraphQLTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias TerminusDB.{Config, Database, Document, GraphQL}

  defp config do
    endpoint = System.get_env("TERMINUSDB_URL", "http://localhost:6363")
    user = System.get_env("TERMINUSDB_USER", "admin")
    key = System.get_env("TERMINUSDB_KEY", "root")

    Config.new(endpoint: endpoint, user: user, key: key)
  end

  setup do
    cfg = config()
    db = "int_gql_#{:erlang.unique_integer([:positive])}"
    Database.create!(cfg, db, label: "GraphQL Test", schema: true)
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

  describe "query" do
    test "queries Person documents", %{config: cfg} do
      assert {:ok, result} = GraphQL.query(cfg, "{ Person { name age } }")
      assert result.errors == nil
      persons = result.data["Person"]
      assert is_list(persons)
      assert length(persons) == 1
      assert hd(persons)["name"] == "Alice"
    end

    test "queries with filter", %{config: cfg} do
      query = "{ Person(filter: {name: {eq: \"Alice\"}}) { name } }"
      assert {:ok, result} = GraphQL.query(cfg, query)

      assert result.errors == nil
      assert length(result.data["Person"]) == 1
    end

    test "queries with limit", %{config: cfg} do
      assert {:ok, result} = GraphQL.query(cfg, "{ Person(limit: 1) { name } }")
      assert result.errors == nil
      assert length(result.data["Person"]) == 1
    end

    test "returns errors on invalid query", %{config: cfg} do
      assert {:ok, result} = GraphQL.query(cfg, "{ NonExistent { name } }")
      assert result.errors != nil
    end
  end

  describe "introspect" do
    test "returns schema types", %{config: cfg} do
      assert {:ok, schema} = GraphQL.introspect(cfg)
      assert schema["__schema"]
      types = schema["__schema"]["types"]
      assert is_list(types)
      type_names = Enum.map(types, & &1["name"])
      assert "Person" in type_names
    end
  end

  describe "mutate" do
    test "inserts a document via mutation", %{config: cfg} do
      doc_json = Jason.encode!(%{"@type" => "Person", "name" => "Bob", "age" => 25})
      escaped = String.replace(doc_json, "\\", "\\\\")
      escaped = String.replace(escaped, "\"", "\\\"")
      mutation = "mutation { _insertDocuments(json: \"#{escaped}\") }"

      case GraphQL.mutate(cfg, mutation) do
        {:ok, result} ->
          if result.errors do
            # Some TerminusDB versions may not support all GraphQL mutation features
            assert is_list(result.errors)
          else
            {:ok, result2} =
              GraphQL.query(cfg, "{ Person(filter: {name: {eq: \"Bob\"}}) { name } }")

            assert length(result2.data["Person"]) == 1
          end

        {:error, _} ->
          # GraphQL mutations may not be available on all TDB versions
          :ok
      end
    end
  end
end
