defmodule TerminusDB.GraphQLTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, GraphQL}

  defp config(resp, status \\ 200) do
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

  describe "query/3" do
    test "returns data and errors" do
      cfg = config(%{"data" => %{"Person" => [%{"name" => "Alice"}]}, "errors" => nil})

      assert {:ok, result} = GraphQL.query(cfg, "{ Person { name } }")
      assert result.data["Person"] == [%{"name" => "Alice"}]
      assert result.errors == nil
    end

    test "returns errors when query fails" do
      cfg = config(%{"data" => nil, "errors" => [%{"message" => "Cannot query field Foo"}]})

      assert {:ok, result} = GraphQL.query(cfg, "{ Foo { name } }")
      assert result.data == nil
      assert length(result.errors) == 1
    end

    test "accepts variables map" do
      cfg = config(%{"data" => %{"Person" => [%{"name" => "Bob"}]}})

      assert {:ok, result} =
               GraphQL.query(
                 cfg,
                 "query($name: String) { Person(filter: {name: {eq: $name}}) { name } }",
                 %{"name" => "Bob"}
               )

      assert result.data["Person"] == [%{"name" => "Bob"}]
    end

    test "accepts variables via opts" do
      cfg = config(%{"data" => %{"Person" => [%{"name" => "Bob"}]}})

      assert {:ok, result} =
               GraphQL.query(cfg, "query($name: String) { Person { name } }",
                 variables: %{"name" => "Bob"}
               )

      assert result.data["Person"] == [%{"name" => "Bob"}]
    end
  end

  describe "mutate/3" do
    test "returns mutation result" do
      cfg = config(%{"data" => %{"_insertDocuments" => ["Person/Alice"]}})

      mutation =
        "mutation { _insertDocuments(json: \"{\\\"@type\\\":\\\"Person\\\",\\\"name\\\":\\\"Alice\\\"}\") }"

      assert {:ok, result} = GraphQL.mutate(cfg, mutation)
      assert result.data["_insertDocuments"] == ["Person/Alice"]
    end
  end

  describe "introspect/2" do
    test "returns schema map" do
      cfg = config(%{"data" => %{"__schema" => %{"types" => [%{"name" => "Person"}]}}})

      assert {:ok, schema} = GraphQL.introspect(cfg)
      assert schema["__schema"]["types"] == [%{"name" => "Person"}]
    end

    test "returns error on transport failure" do
      cfg = config(%{"errors" => [%{"message" => "Unauthorized"}]}, 401)

      assert {:error, _} = GraphQL.introspect(cfg)
    end
  end

  describe "error handling" do
    test "returns error on HTTP failure" do
      cfg = config(%{"api:message" => "bad request"}, 400)

      assert {:error, _} = GraphQL.query(cfg, "{ Foo { name } }")
    end

    test "returns error on 500" do
      cfg = config(%{"api:message" => "internal error"}, 500)

      assert {:error, _} = GraphQL.mutate(cfg, "mutation { _insertDocuments(json: \"{}\") }")
    end

    test "returns nil errors when not present" do
      cfg = config(%{"data" => %{"Person" => []}})

      assert {:ok, result} = GraphQL.query(cfg, "{ Person { name } }")
      assert result.errors == nil
      assert result.data == %{"Person" => []}
    end

    test "raises when no database is scoped" do
      cfg =
        Config.new(
          endpoint: "http://localhost:6363",
          adapter: fn req -> {req, Req.Response.new(status: 200, body: %{})} end
        )

      assert_raise TerminusDB.Error, fn -> GraphQL.query(cfg, "{ Person { name } }") end
    end

    test "honors :organization override" do
      cfg =
        Config.with_database(
          Config.new(
            endpoint: "http://localhost:6363",
            user: "admin",
            key: "root",
            adapter: fn req ->
              {req, Req.Response.new(status: 200, body: %{"data" => %{}})}
            end
          ),
          "mydb"
        )

      assert {:ok, _} = GraphQL.query(cfg, "{ Person { name } }", organization: "acme")
    end
  end
end
