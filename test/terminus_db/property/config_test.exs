defmodule TerminusDB.Property.ConfigTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TerminusDB.Config

  property "with_database/2 only changes :database and preserves all other fields" do
    check all(db <- string(:alphanumeric, min_length: 1, max_length: 50)) do
      original = Config.new(endpoint: "http://localhost:6363", organization: "acme")
      scoped = Config.with_database(original, db)

      assert scoped.database == db
      assert scoped.endpoint == original.endpoint
      assert scoped.organization == original.organization
      assert scoped.branch == original.branch
      assert scoped.repo == original.repo
      assert scoped.user == original.user
      assert scoped.key == original.key
    end
  end

  property "with_branch/2 only changes :branch and preserves :database" do
    check all(
            branch <- string(:alphanumeric, min_length: 1, max_length: 50),
            db <- string(:alphanumeric, min_length: 1, max_length: 50)
          ) do
      config =
        Config.new(endpoint: "http://x")
        |> Config.with_database(db)
        |> Config.with_branch(branch)

      assert config.branch == branch
      assert config.database == db
    end
  end

  property "redact/1 always replaces non-nil key and token with [redacted]" do
    check all(
            key <- string(:alphanumeric, min_length: 1),
            token <- string(:alphanumeric, min_length: 1)
          ) do
      config = Config.new(endpoint: "http://x", key: key, token: token)
      redacted = Config.redact(config)

      assert redacted.key == "[redacted]"
      assert redacted.token == "[redacted]"
      assert redacted.endpoint == "http://x"
    end
  end

  property "redact/1 leaves a nil token untouched while redacting the key" do
    check all(key <- string(:alphanumeric, min_length: 1)) do
      config = Config.new(endpoint: "http://x", key: key)
      redacted = Config.redact(config)

      assert redacted.key == "[redacted]"
      assert redacted.token == nil
      assert redacted.endpoint == "http://x"
    end
  end

  property "auth/1 returns {:bearer, token} when a token is set, regardless of user/key" do
    check all(
            token <- string(:alphanumeric, min_length: 1),
            user <- string(:alphanumeric, min_length: 1),
            key <- string(:alphanumeric, min_length: 1)
          ) do
      config = Config.new(endpoint: "http://x", token: token, user: user, key: key)
      assert Config.auth(config) == {:bearer, token}
    end
  end

  property "auth/1 returns {:basic, user:key} when no token is set" do
    check all(
            user <- string(:alphanumeric, min_length: 1),
            key <- string(:alphanumeric, min_length: 1)
          ) do
      config = Config.new(endpoint: "http://x", user: user, key: key)
      assert Config.auth(config) == {:basic, "#{user}:#{key}"}
    end
  end
end
