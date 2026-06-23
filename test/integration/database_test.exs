defmodule TerminusDB.Integration.DatabaseTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias TerminusDB.{Config, Database}

  @db_name "integration_test_#{:rand.uniform(1_000_000)}"

  defp config do
    endpoint = System.get_env("TERMINUSDB_URL", "http://localhost:6363")
    user = System.get_env("TERMINUSDB_USER", "admin")
    key = System.get_env("TERMINUSDB_KEY", "root")

    Config.new(endpoint: endpoint, user: user, key: key)
  end

  describe "connectivity" do
    test "server is reachable and reports ok" do
      {:ok, _} = TerminusDB.Client.request(config(), :get, "ok")
    end

    test "server reports version info" do
      {:ok, body} = TerminusDB.Client.request(config(), :get, "info")
      assert is_map(body)
      assert body["api:status"] == "api:success"
    end
  end

  describe "database lifecycle" do
    setup do
      on_exit(fn ->
        Database.delete(config(), @db_name, force: true)
      end)
    end

    test "create, exists?, info, and delete" do
      cfg = config()

      # Create
      {:ok, create_resp} =
        Database.create(cfg, @db_name,
          label: "Integration Test DB",
          comment: "Created by the integration test suite",
          schema: true
        )

      assert create_resp["api:status"] == "api:success"

      # Exists
      assert Database.exists?(cfg, @db_name) == true

      # Info
      {:ok, details} = Database.info(cfg, @db_name)
      assert is_list(details)
      assert Enum.any?(details, &(&1["name"] == @db_name))

      # Delete
      {:ok, delete_resp} = Database.delete(cfg, @db_name)
      assert delete_resp["api:status"] == "api:success"

      # No longer exists
      assert Database.exists?(cfg, @db_name) == false
    end

    test "list returns all databases including ours" do
      cfg = config()

      Database.create!(cfg, @db_name, label: "L", schema: true)

      {:ok, dbs} = Database.list(cfg)
      names = Enum.map(dbs, & &1["name"])
      assert @db_name in names
    end

    test "create returns an :api error when the database already exists" do
      cfg = config()

      Database.create!(cfg, @db_name, label: "L", schema: true)

      assert {:error, %TerminusDB.Error{reason: :api}} =
               Database.create(cfg, @db_name, label: "L", schema: true)
    end
  end
end
