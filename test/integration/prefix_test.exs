defmodule TerminusDB.Integration.PrefixTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias TerminusDB.{Config, Database, Prefix}

  defp config do
    endpoint = System.get_env("TERMINUSDB_URL", "http://localhost:6363")
    user = System.get_env("TERMINUSDB_USER", "admin")
    key = System.get_env("TERMINUSDB_KEY", "root")

    Config.new(endpoint: endpoint, user: user, key: key)
  end

  setup do
    cfg = config()
    db = "int_prefix_#{:erlang.unique_integer([:positive])}"
    Database.create!(cfg, db, label: "Prefix Test", schema: true)
    scoped = Config.with_database(cfg, db)

    on_exit(fn ->
      Database.delete(cfg, db, force: true)
    end)

    {:ok, config: scoped}
  end

  describe "prefix CRUD" do
    test "add, get, update, delete a prefix", %{config: cfg} do
      assert {:ok, _} = Prefix.add(cfg, "ex", "http://example.org/")

      assert {:ok, uri} = Prefix.get(cfg, "ex")
      assert uri == "http://example.org/"

      assert {:ok, _} = Prefix.update(cfg, "ex", "http://example.com/")
      assert {:ok, uri2} = Prefix.get(cfg, "ex")
      assert uri2 == "http://example.com/"

      assert {:ok, _} = Prefix.delete(cfg, "ex")
      assert {:error, _} = Prefix.get(cfg, "ex")
    end

    test "upsert creates or updates", %{config: cfg} do
      assert {:ok, _} = Prefix.upsert(cfg, "test", "http://test.org/")
      assert {:ok, _} = Prefix.upsert(cfg, "test", "http://test2.org/")
      assert {:ok, uri} = Prefix.get(cfg, "test")
      assert uri == "http://test2.org/"
    end

    test "all returns default prefixes", %{config: cfg} do
      assert {:ok, prefixes} = Prefix.all(cfg)
      assert prefixes["@base"]
      assert prefixes["@schema"]
    end
  end
end
