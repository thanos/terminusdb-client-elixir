# terminusdb_ex

An idiomatic, production-quality Elixir client for [TerminusDB](https://terminusdb.org) —
the document graph database with built-in version control.

`terminusdb_ex` exposes database management, document/schema APIs, WOQL, GraphQL,
telemetry, and streaming, with optional Ecto and ExDatalog integrations planned. It is
built on [Req](https://hexdocs.pm/req) and treats connection context as **immutable data**,
making it safe for concurrent use.

> **Status:** v0.1 (foundation) — `Config`, `Error`, `Telemetry`, `Client`, and the
> `Database` management API are implemented and tested. Document/Schema/Branch/Commit/
> Diff/Merge/WOQL/GraphQL APIs, Ecto, and ExDatalog land in later milestones. See
> `ARCHITECTURE.md` and `AGENTS.md` for the roadmap.

## Installation

Add `terminusdb_client` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:terminusdb_client, "~> 0.1.0"}
  ]
end
```

Then run `mix deps.get`.

## Quick start

```elixir
# 1. Configure a connection (immutable context). Default auth is admin:root.
config = TerminusDB.Config.new(endpoint: "http://localhost:6363")

# 2. Create a database.
{:ok, _} =
  TerminusDB.Database.create(config, "mydb",
    label: "My Database",
    comment: "A demo database",
    schema: true
  )

# 3. Inspect it.
{:ok, details} = TerminusDB.Database.info(config, "mydb")
true = TerminusDB.Database.exists?(config, "mydb")

# 4. Scope the config to a database (for later document work).
config = TerminusDB.Config.with_database(config, "mydb")

# 5. Clean up.
:ok = TerminusDB.Database.delete(config, "mydb")
```

All public functions return `{:ok, result}` or `{:error, %TerminusDB.Error{}}`. Each
`!/1`-suffixed variant raises `TerminusDB.Error` instead.

## Authentication

Basic auth (default `admin`/`root`) or a bearer token:

```elixir
config = TerminusDB.Config.new(endpoint: "http://localhost:6363", token: "tok_abc")
```

## Telemetry

Every operation emits `[:terminusdb, <area>, :start]` and `[:stop]` events
(`<area>` ∈ `:database`, `:document`, `:query`, `:branch`, `:merge`, `:diff`,
`:connection`). Attach with `:telemetry.attach_many/4`. See `TerminusDB.Telemetry`
and ADR-0005.

```elixir
:telemetry.attach_many(
  "my-handler",
  [[:terminusdb, :database, :stop]],
  fn _event, %{duration: dur}, meta, _ctx ->
    :telemetry.execute(:my_app, %{db_duration: dur}, %{path: meta.path})
  end,
  nil
)
```

## Development

```bash
mix deps.get
mix test                 # hermetic unit + doctests
mix coveralls            # coverage (target 80%)
mix quality              # format + credo + sobelow + dialyzer
```

Integration tests run against a Dockerized TerminusDB:

```bash
docker compose up -d
mix test --only integration
docker compose down
```

See `AGENTS.md` for the full operating guide and `ARCHITECTURE.md` + `docs/adr/` for
the design.

## License

Copyright 2026 TerminusDB Contributors. Licensed under the Apache License, Version 2.0 —
see [LICENSE](LICENSE).
