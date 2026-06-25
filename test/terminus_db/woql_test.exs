defmodule TerminusDB.WOQLTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Error, WOQL}
  import TerminusDB.Test.Helpers

  doctest TerminusDB.WOQL

  describe "triple/3" do
    test "builds a triple query" do
      q = WOQL.triple("v:S", "name", "v:N")
      assert q.op == :triple
      assert q.args == ["v:S", "name", "v:N"]
    end
  end

  describe "and_/1" do
    test "builds a conjunction" do
      q = WOQL.and_([WOQL.triple("v:S", "p", "v:O"), WOQL.eq("v:O", "Alice")])
      assert q.op == :and
      assert q.args != []
    end
  end

  describe "or_/1" do
    test "builds a disjunction" do
      q = WOQL.or_([WOQL.eq("v:N", "Alice"), WOQL.eq("v:N", "Bob")])
      assert q.op == :or
      assert q.args != []
    end
  end

  describe "eq/2" do
    test "builds an equality" do
      q = WOQL.eq("v:N", "Alice")
      assert q.op == :eq
      assert q.args == ["v:N", "Alice"]
    end
  end

  describe "select/2" do
    test "builds a select with variables and sub-query" do
      q = WOQL.select(["v:Name"], WOQL.triple("v:P", "name", "v:Name"))
      assert q.op == :select
      assert q.args == [["v:Name"], %WOQL{op: :triple, args: ["v:P", "name", "v:Name"]}]
    end
  end

  describe "read_document/2" do
    test "builds a read_document query" do
      q = WOQL.read_document("Person/Alice", "v:Doc")
      assert q.op == :read_document
      assert q.args == ["Person/Alice", "v:Doc"]
    end
  end

  describe "type_of/2" do
    test "builds a type_of query" do
      q = WOQL.type_of("v:Person", "v:Type")
      assert q.op == :type_of
      assert q.args == ["v:Person", "v:Type"]
    end
  end

  describe "to_jsonld/1" do
    test "encodes a triple with variables" do
      jsonld = WOQL.to_jsonld(WOQL.triple("v:Person", "name", "v:Name"))

      assert jsonld["@type"] == "Triple"
      assert jsonld["subject"] == %{"@type" => "NodeValue", "variable" => "Person"}
      assert jsonld["predicate"] == %{"@type" => "NodeValue", "node" => "name"}
      assert jsonld["object"] == %{"@type" => "DataValue", "variable" => "Name"}
    end

    test "encodes a triple with constant nodes" do
      jsonld = WOQL.to_jsonld(WOQL.triple("v:Person", "rdf:type", "@schema:Person"))

      assert jsonld["predicate"] == %{"@type" => "NodeValue", "node" => "rdf:type"}
      assert jsonld["object"] == "@schema:Person"
    end

    test "encodes an and query" do
      jsonld = WOQL.to_jsonld(WOQL.and_([WOQL.triple("v:S", "p", "v:O")]))

      assert jsonld["@type"] == "And"
      assert is_list(jsonld["and"])
      assert length(jsonld["and"]) == 1
    end

    test "encodes an or query" do
      jsonld = WOQL.to_jsonld(WOQL.or_([WOQL.eq("v:N", "Alice")]))

      assert jsonld["@type"] == "Or"
      assert length(jsonld["or"]) == 1
    end

    test "encodes an eq query" do
      jsonld = WOQL.to_jsonld(WOQL.eq("v:N", "Alice"))

      assert jsonld["@type"] == "Equals"
      assert jsonld["left"] == %{"@type" => "DataValue", "variable" => "N"}

      assert jsonld["right"] == %{
               "@type" => "DataValue",
               "data" => %{"@type" => "xsd:string", "@value" => "Alice"}
             }
    end

    test "encodes a select query" do
      jsonld = WOQL.to_jsonld(WOQL.select(["v:Name"], WOQL.triple("v:P", "name", "v:Name")))

      assert jsonld["@type"] == "Select"
      assert jsonld["variables"] == ["Name"]
      assert jsonld["query"]["@type"] == "Triple"
    end

    test "encodes a read_document query" do
      jsonld = WOQL.to_jsonld(WOQL.read_document("Person/Alice", "v:Doc"))

      assert jsonld["@type"] == "ReadDocument"
      assert jsonld["document"] == %{"@type" => "NodeValue", "node" => "Person/Alice"}
      assert jsonld["identifier"] == %{"@type" => "DataValue", "variable" => "Doc"}
    end

    test "encodes a type_of query" do
      jsonld = WOQL.to_jsonld(WOQL.type_of("v:Person", "v:Type"))

      assert jsonld["@type"] == "TypeOf"
      assert jsonld["node"] == %{"@type" => "NodeValue", "variable" => "Person"}
      assert jsonld["type"] == %{"@type" => "NodeValue", "variable" => "Type"}
    end

    test "encodes numeric and boolean values" do
      jsonld = WOQL.to_jsonld(WOQL.eq("v:Age", 30))

      assert jsonld["right"] == %{
               "@type" => "DataValue",
               "data" => %{"@type" => "xsd:integer", "@value" => 30}
             }

      jsonld2 = WOQL.to_jsonld(WOQL.eq("v:Active", true))

      assert jsonld2["right"] == %{
               "@type" => "DataValue",
               "data" => %{"@type" => "xsd:boolean", "@value" => true}
             }
    end
  end

  describe "from_jsonld/1" do
    test "decodes a triple" do
      jsonld = %{
        "@type" => "Triple",
        "subject" => %{"@type" => "NodeValue", "variable" => "S"},
        "predicate" => %{"@type" => "NodeValue", "node" => "name"},
        "object" => %{"@type" => "DataValue", "variable" => "N"}
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :triple
      assert q.args == ["v:S", "name", "v:N"]
    end

    test "decodes an and query" do
      jsonld = %{
        "@type" => "And",
        "and" => [
          %{
            "@type" => "Triple",
            "subject" => %{"@type" => "NodeValue", "variable" => "S"},
            "predicate" => %{"@type" => "NodeValue", "node" => "p"},
            "object" => %{"@type" => "DataValue", "variable" => "O"}
          }
        ]
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :and
      assert q.args != []
    end

    test "decodes an eq query" do
      jsonld = %{
        "@type" => "Equals",
        "left" => %{"@type" => "DataValue", "variable" => "N"},
        "right" => %{
          "@type" => "DataValue",
          "data" => %{"@type" => "xsd:string", "@value" => "Alice"}
        }
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :eq
      assert q.args == ["v:N", "Alice"]
    end

    test "decodes a select query" do
      jsonld = %{
        "@type" => "Select",
        "variables" => ["Name"],
        "query" => %{
          "@type" => "Triple",
          "subject" => %{"@type" => "NodeValue", "variable" => "P"},
          "predicate" => %{"@type" => "NodeValue", "node" => "name"},
          "object" => %{"@type" => "DataValue", "variable" => "Name"}
        }
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :select
      assert q.args == [["v:Name"], %WOQL{op: :triple, args: ["v:P", "name", "v:Name"]}]
    end
  end

  describe "round-trip: to_jsonld ∘ from_jsonld" do
    test "round-trips a triple" do
      q = WOQL.triple("v:Person", "name", "v:Name")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips an and query" do
      q = WOQL.and_([WOQL.triple("v:S", "p", "v:O"), WOQL.eq("v:O", "Alice")])
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips a select query" do
      q = WOQL.select(["v:Name"], WOQL.triple("v:P", "name", "v:Name"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips an eq query" do
      q = WOQL.eq("v:N", "Alice")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips a type_of query" do
      q = WOQL.type_of("v:Person", "v:Type")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "execute/3" do
    test "POSTs to woql/:org/:db/:repo/branch/:branch with the query as JSON-LD" do
      test = self()

      adapter =
        capture(
          test,
          Req.Response.new(status: 200, body: %{"bindings" => [%{"Name" => "Alice"}]})
        )

      config =
        Config.with_database(
          Config.new(endpoint: "http://localhost:6363", adapter: adapter),
          "mydb"
        )

      q = WOQL.select(["v:Name"], WOQL.and_([WOQL.triple("v:P", "name", "v:Name")]))

      assert {:ok, result} = WOQL.execute(config, q)

      req = last_request()
      assert req.method == :post
      assert req.url.path == "/api/woql/admin/mydb/local/branch/main"

      assert {:ok, body} = Jason.decode(req.body)
      assert body["query"]["@type"] == "Select"
      assert result["bindings"] == [%{"Name" => "Alice"}]
    end

    test "includes commit_info when :author and :message are provided" do
      test = self()
      adapter = capture(test, ok(%{"bindings" => []}))

      config =
        Config.with_database(
          Config.new(endpoint: "http://localhost:6363", adapter: adapter),
          "mydb"
        )

      WOQL.execute(config, WOQL.triple("v:S", "p", "v:O"),
        author: "admin",
        message: "write query"
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["commit_info"]["author"] == "admin"
      assert body["commit_info"]["message"] == "write query"
    end

    test "raises when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)

      assert_raise Error, fn ->
        WOQL.execute(config, WOQL.triple("v:S", "p", "v:O"))
      end
    end
  end

  describe "execute!/3" do
    test "returns the result on success" do
      adapter = fn req -> {req, ok(%{"bindings" => []})} end

      config =
        Config.with_database(
          Config.new(endpoint: "http://localhost:6363", adapter: adapter),
          "mydb"
        )

      assert WOQL.execute!(config, WOQL.triple("v:S", "p", "v:O")) == %{"bindings" => []}
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(400, %{"@type" => "api:bad"})} end

      config =
        Config.with_database(
          Config.new(endpoint: "http://localhost:6363", adapter: adapter),
          "mydb"
        )

      assert_raise Error, fn ->
        WOQL.execute!(config, WOQL.triple("v:S", "p", "v:O"))
      end
    end
  end
end
