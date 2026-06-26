defmodule TerminusDB.TriplesTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Triples}

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

  describe "get/2" do
    test "returns turtle string" do
      cfg = config("@prefix : <http://example.org/> .")
      assert {:ok, turtle} = Triples.get(cfg)
      assert turtle == "@prefix : <http://example.org/> ."
    end

    test "get! returns turtle or raises" do
      cfg = config("@prefix : <http://example.org/> .")
      assert Triples.get!(cfg) == "@prefix : <http://example.org/> ."
    end
  end

  describe "update/3" do
    test "replaces graph with turtle" do
      cfg = config()

      assert {:ok, resp} =
               Triples.update(cfg, ":foo :bar :baz .", author: "admin", message: "replace")

      assert resp["api:status"] == "api:success"
    end

    test "update! returns response or raises" do
      cfg = config()
      assert Triples.update!(cfg, ":foo :bar :baz .")["api:status"] == "api:success"
    end
  end

  describe "insert/3" do
    test "inserts turtle additively" do
      cfg = config()

      assert {:ok, resp} =
               Triples.insert(cfg, ":foo :bar :baz .", author: "admin", message: "add")

      assert resp["api:status"] == "api:success"
    end

    test "insert! returns response or raises" do
      cfg = config()
      assert Triples.insert!(cfg, ":foo :bar :baz .")["api:status"] == "api:success"
    end
  end
end
