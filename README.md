# terminusdb_ex

[![Hex.pm Version](https://img.shields.io/hexpm/v/terminusdb_client.svg)](https://hex.pm/packages/terminusdb_client)
[![Hex.pm License](https://img.shields.io/hexpm/l/terminusdb_client.svg)](https://hex.pm/packages/terminusdb_client)
[![HexDocs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/terminusdb_client)
[![CI](https://github.com/thanos/terminusdb-client-elixir/actions/workflows/ci.yml/badge.svg)](https://github.com/thanos/terminusdb-client-elixir/actions/workflows/ci.yml)
[![Coverage](https://coveralls.io/repos/github/thanos/terminusdb-client-elixir/badge.svg?branch=main)](https://coveralls.io/github/thanos/terminusdb-client-elixir)

An idiomatic Elixir client for [TerminusDB](https://terminusdb.org), the document
graph database with built-in version control. It is built on
[Req](https://hexdocs.pm/req) and treats connection context as **immutable data**,
making it safe for concurrent use.

> **Status:** v0.1 (foundation). `Config`, `Error`, `Telemetry`, `Client`, and the
> `Database` management API are implemented and tested. Document, schema, branch,
> commit, diff, merge, WOQL, GraphQL, and streaming APIs, plus optional Ecto and
> ExDatalog integrations, are planned for later milestones. See `ARCHITECTURE.md`
> and `AGENTS.md` for the roadmap.

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
(`<area>` is `:database`, `:document`, `:query`, `:branch`, `:merge`, `:diff`, or
`:connection`). Attach with `:telemetry.attach_many/4`. See `TerminusDB.Telemetry`
and ADR-0005.

```elixir
:telemetry.attach_many(
  "my-handler",
  [[:terminusdb, :database, :stop]],
  fn _event, %{duration: duration}, meta, _ctx ->
    :telemetry.execute([:my_app, :db, :duration], %{duration: duration}, %{path: meta.path})
  end,
  nil
)
```

## Development

```bash
mix deps.get
mix test                 # hermetic unit + doctests
mix coveralls            # coverage (target 80%, enforced via coveralls.json)
mix quality              # format + credo + sobelow + dialyzer
mix verify               # full quality gate + tests + docs
```

Integration tests run against a Dockerized TerminusDB (the image has no in-container
healthcheck, so poll from the host):

```bash
docker compose up -d
until curl -sf http://localhost:6363/api/ok >/dev/null 2>&1; do sleep 1; done
mix test --only integration
docker compose down
```

See `AGENTS.md` for the full operating guide and `ARCHITECTURE.md` + `docs/adr/` for
the design.

## License

Copyright 2026 TerminusDB Contributors. Licensed under the Apache License, Version 2.0.
See [LICENSE](LICENSE).
