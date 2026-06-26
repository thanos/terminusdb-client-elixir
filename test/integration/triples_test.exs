defmodule TerminusDB.Integration.TriplesTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias TerminusDB.{Config, Database, Triples}

  defp config do
    endpoint = System.get_env("TERMINUSDB_URL", "http://localhost:6363")
    user = System.get_env("TERMINUSDB_USER", "admin")
    key = System.get_env("TERMINUSDB_KEY", "root")

    Config.new(endpoint: endpoint, user: user, key: key)
  end

  setup do
    cfg = config()
    db = "int_triples_#{:erlang.unique_integer([:positive])}"
    Database.create!(cfg, db, label: "Triples Test", schema: true)
    scoped = Config.with_database(cfg, db)

    on_exit(fn ->
      Database.delete(cfg, db, force: true)
    end)

    {:ok, config: scoped}
  end

  describe "triples" do
    test "get schema triples returns turtle", %{config: cfg} do
      assert {:ok, turtle} = Triples.get(cfg, graph_type: :schema)
      assert is_binary(turtle)
    end

    test "get instance triples returns turtle", %{config: cfg} do
      assert {:ok, turtle} = Triples.get(cfg, graph_type: :instance)
      assert is_binary(turtle)
    end

    test "insert and update triples", %{config: cfg} do
      turtle =
        "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> . <http://example.org/foo> <http://example.org/bar> \"baz\"^^xsd:string ."

      assert {:ok, _} =
               Triples.insert(cfg, turtle,
                 graph_type: :instance,
                 author: "admin",
                 message: "insert"
               )

      assert {:ok, _} =
               Triples.update(cfg, turtle,
                 graph_type: :instance,
                 author: "admin",
                 message: "replace"
               )
    end
  end
end
