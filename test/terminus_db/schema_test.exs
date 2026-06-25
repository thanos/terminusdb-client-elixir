defmodule TerminusDB.SchemaTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Error, Schema}
  import TerminusDB.Test.Helpers

  defp db_config(adapter) do
    Config.with_database(Config.new(endpoint: "http://localhost:6363", adapter: adapter), "mydb")
  end

  describe "frame/3" do
    test "GETs schema/:org/:db for all classes when class_name is nil" do
      test = self()

      frame = %{
        "@context" => %{"@type" => "Context"},
        "Person" => %{"@type" => "Class", "name" => "xsd:string"}
      }

      adapter = capture(test, Req.Response.new(status: 200, body: frame))

      assert {:ok, ^frame} = Schema.frame(db_config(adapter))
      req = last_request()
      assert req.method == :get
      assert req.url.path == "/api/schema/admin/mydb"
    end

    test "GETs schema/:org/:db/:class for a specific class" do
      test = self()

      frame = %{"@type" => "Class", "name" => "xsd:string"}

      adapter = capture(test, Req.Response.new(status: 200, body: frame))

      assert {:ok, ^frame} = Schema.frame(db_config(adapter), "Person")
      req = last_request()
      assert req.url.path == "/api/schema/admin/mydb"
    end

    test "passes compress_ids and expand_abstract params" do
      test = self()
      adapter = capture(test, ok(%{}))

      Schema.frame(db_config(adapter), "Person",
        compress_ids: false,
        expand_abstract: false
      )

      req = last_request()
      assert req.url.query =~ "compress_ids=false"
      assert req.url.query =~ "expand_abstract=false"
    end

    test "honors :organization override" do
      test = self()
      adapter = capture(test, ok(%{}))

      Schema.frame(db_config(adapter), "Person", organization: "acme")
      req = last_request()
      assert req.url.path == "/api/schema/acme/mydb"
    end

    test "raises when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)
      assert_raise Error, fn -> Schema.frame(config, "Person") end
    end
  end

  describe "frame!/3" do
    test "returns the frame on success" do
      adapter = fn req -> {req, ok(%{"@type" => "Class"})} end
      assert Schema.frame!(db_config(adapter), "Person") == %{"@type" => "Class"}
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(404, %{"@type" => "api:NotFound"})} end
      assert_raise Error, fn -> Schema.frame!(db_config(adapter), "Missing") end
    end
  end

  describe "all/2" do
    test "is equivalent to frame(config, nil)" do
      test = self()
      adapter = capture(test, ok(%{}))

      Schema.all(db_config(adapter))
      req = last_request()
      assert req.url.path == "/api/schema/admin/mydb"
    end
  end

  describe "all!/2" do
    test "returns all frames on success" do
      adapter = fn req -> {req, ok(%{"Person" => %{}})} end
      assert Schema.all!(db_config(adapter)) == %{"Person" => %{}}
    end
  end
end
