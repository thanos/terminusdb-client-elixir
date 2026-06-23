defmodule TerminusDB.ConfigTest do
  use ExUnit.Case, async: true

  doctest TerminusDB.Config

  describe "new/1" do
    test "requires an endpoint" do
      assert_raise NimbleOptions.ValidationError, ~r/required :endpoint option not found/, fn ->
        TerminusDB.Config.new([])
      end
    end

    test "applies defaults for auth and resource scope" do
      config = TerminusDB.Config.new(endpoint: "http://localhost:6363")

      assert config.endpoint == "http://localhost:6363"
      assert config.user == "admin"
      assert config.key == "root"
      assert config.organization == "admin"
      assert config.branch == "main"
      assert config.repo == "local"
      assert config.database == nil
      assert config.ref == nil
      assert config.telemetry == true
      assert config.receive_timeout == 15_000
      assert config.user_agent == "terminusdb_ex/0.1.0"
    end

    test "accepts overrides" do
      config =
        TerminusDB.Config.new(
          endpoint: "http://hub:6363",
          user: "alice",
          key: "s3cret",
          organization: "acme",
          database: "foo",
          branch: "feature",
          repo: "origin",
          receive_timeout: 5_000,
          telemetry: false
        )

      assert config.user == "alice"
      assert config.organization == "acme"
      assert config.database == "foo"
      assert config.branch == "feature"
      assert config.repo == "origin"
      assert config.receive_timeout == 5_000
      assert config.telemetry == false
    end

    test "validates types" do
      assert_raise NimbleOptions.ValidationError, ~r/expected string, got: 123/, fn ->
        TerminusDB.Config.new(endpoint: 123)
      end
    end
  end

  describe "auth/1" do
    test "prefers bearer token over basic" do
      config = TerminusDB.Config.new(endpoint: "http://x", token: "tok", user: "u", key: "k")
      assert TerminusDB.Config.auth(config) == {:bearer, "tok"}
    end

    test "uses basic auth from user/key" do
      config = TerminusDB.Config.new(endpoint: "http://x", user: "admin", key: "root")
      assert TerminusDB.Config.auth(config) == {:basic, "admin:root"}
    end

    test "empty token falls back to basic" do
      config = TerminusDB.Config.new(endpoint: "http://x", token: "", user: "u", key: "k")
      assert TerminusDB.Config.auth(config) == {:basic, "u:k"}
    end

    test "returns nil when no credentials are usable" do
      # A struct built directly (bypassing NimbleOptions) with non-string user/key
      # hits the final auth clause that returns nil.
      config = %TerminusDB.Config{endpoint: "http://x", user: nil, key: nil}
      assert TerminusDB.Config.auth(config) == nil
    end
  end

  describe "schema/0" do
    test "returns the NimbleOptions schema as a keyword list" do
      schema = TerminusDB.Config.schema()

      assert is_list(schema)
      assert Keyword.keyword?(schema)
      assert Keyword.has_key?(schema, :endpoint)
      assert Keyword.has_key?(schema, :token)
      assert Keyword.has_key?(schema, :user)
      assert Keyword.has_key?(schema, :key)
      assert Keyword.has_key?(schema, :organization)
      assert Keyword.has_key?(schema, :database)
      assert Keyword.has_key?(schema, :branch)
      assert Keyword.has_key?(schema, :repo)
      assert Keyword.has_key?(schema, :adapter)
      assert Keyword.has_key?(schema, :telemetry)
    end
  end

  describe "scoping" do
    test "with_* functions return derived configs without mutation" do
      config = TerminusDB.Config.new(endpoint: "http://x")

      scoped =
        config
        |> TerminusDB.Config.with_organization("acme")
        |> TerminusDB.Config.with_database("db")
        |> TerminusDB.Config.with_branch("dev")
        |> TerminusDB.Config.with_repo("origin")
        |> TerminusDB.Config.with_ref("commit/abc")

      assert scoped.organization == "acme"
      assert scoped.database == "db"
      assert scoped.branch == "dev"
      assert scoped.repo == "origin"
      assert scoped.ref == "commit/abc"

      # original is unchanged
      assert config.organization == "admin"
      assert config.database == nil
    end
  end

  describe "redact/1" do
    test "redacts key and token, keeps endpoint" do
      config = TerminusDB.Config.new(endpoint: "http://x", key: "secret", token: "tok")
      redacted = TerminusDB.Config.redact(config)

      assert redacted.key == "[redacted]"
      assert redacted.token == "[redacted]"
      assert redacted.endpoint == "http://x"
    end

    test "leaves a nil token untouched while redacting the defaulted key" do
      config = TerminusDB.Config.new(endpoint: "http://x")
      redacted = TerminusDB.Config.redact(config)

      # :key defaults to "root" so it is redacted; :token defaults to nil and stays nil
      assert redacted.key == "[redacted]"
      assert redacted.token == nil
    end
  end
end
