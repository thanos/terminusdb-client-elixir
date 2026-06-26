defmodule TerminusDB.RemoteTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Remote}

  defp config(resp \\ %{"api:status" => "api:success"}, status \\ 200) do
    Config.with_database(
      Config.new(
        endpoint: "http://localhost:6363",
        user: "admin",
        key: "root",
        adapter: fn req -> {req, Req.Response.new(status: status, body: resp)} end
      ),
      "mydb"
    )
  end

  describe "clone/3" do
    test "clones a remote repository" do
      cfg =
        Config.new(
          endpoint: "http://localhost:6363",
          user: "admin",
          key: "root",
          adapter: fn req ->
            {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})}
          end
        )

      assert {:ok, resp} =
               Remote.clone(cfg, "https://data.terminusdb.org/public/star-wars", "star-wars",
                 label: "Star Wars"
               )

      assert resp["api:status"] == "api:success"
    end

    test "clone! returns response or raises" do
      cfg =
        Config.new(
          endpoint: "http://localhost:6363",
          user: "admin",
          key: "root",
          adapter: fn req ->
            {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})}
          end
        )

      assert Remote.clone!(cfg, "https://example.com/db", "newdb")["api:status"] == "api:success"
    end
  end

  describe "fetch/2" do
    test "fetches from remote" do
      cfg = config(%{"api:status" => "api:success", "api:head_has_changed" => true})
      assert {:ok, resp} = Remote.fetch(cfg)
      assert resp["api:head_has_changed"] == true
    end

    test "fetch! returns response or raises" do
      cfg = config(%{"api:head_has_changed" => false})
      assert Remote.fetch!(cfg)["api:head_has_changed"] == false
    end
  end

  describe "push/3" do
    test "pushes to remote" do
      cfg = config(%{"api:repo_head_updated" => true})
      assert {:ok, resp} = Remote.push(cfg, "origin", "main", author: "admin", message: "push")
      assert resp["api:repo_head_updated"] == true
    end

    test "push! returns response or raises" do
      cfg = config(%{"api:repo_head_updated" => true})
      assert Remote.push!(cfg, "origin", "main")["api:repo_head_updated"] == true
    end
  end

  describe "pull/3" do
    test "pulls from remote" do
      cfg = config()
      assert {:ok, resp} = Remote.pull(cfg, "origin", "main", author: "admin", message: "pull")
      assert resp["api:status"] == "api:success"
    end

    test "pull! returns response or raises" do
      cfg = config()
      assert Remote.pull!(cfg, "origin", "main")["api:status"] == "api:success"
    end
  end
end
