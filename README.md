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

> **Status:** v0.2 (in progress). `Config`, `Error`, `Telemetry`, `Client`,
> `Database`, `Document`, `Schema`, `Branch`, and `Streaming` are implemented and
> tested. Commit, diff, merge, WOQL DSL, GraphQL, benchmarks, and guides are
> planned for later. See `ARCHITECTURE.md` and `AGENTS.md` for the roadmap.

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

# 2. Create a database with a schema graph.
{:ok, _} =
  TerminusDB.Database.create(config, "mydb",
    label: "My Database",
    comment: "A demo database",
    schema: true
  )

# 3. Scope the config to the database for document operations.
config = TerminusDB.Config.with_database(config, "mydb")

# 4. Insert a schema (a Class document in the schema graph).
{:ok, _} =
  TerminusDB.Document.insert(config,
    %{"@type" => "Class", "@id" => "Person", "name" => "xsd:string", "age" => "xsd:integer"},
    author: "admin", message: "add Person schema",
    graph_type: :schema
  )

# 5. Insert a document (an instance of Person).
{:ok, _} =
  TerminusDB.Document.insert(config,
    %{"@type" => "Person", "name" => "Alice", "age" => 30},
    author: "admin", message: "add Alice"
  )

# 6. Retrieve documents by type.
{:ok, docs} = TerminusDB.Document.get(config, type: "Person", as_list: true)
# => [%{"@id" => "Person/Alice", "name" => "Alice", "age" => 30}]

# 7. Query by template (match all Person documents with age 30).
{:ok, matches} =
  TerminusDB.Document.query(config, %{"@type" => "Person", "age" => 30})

# 8. Retrieve the schema frame for the Person class.
{:ok, frame} = TerminusDB.Schema.frame(config, "Person")
# => %{"@type" => "Class", "name" => "xsd:string", "age" => "xsd:integer"}

# 9. Create a branch and work on it.
{:ok, _} = TerminusDB.Branch.create(config, "feature")
feature_config = TerminusDB.Config.with_branch(config, "feature")

# 10. Stream large result sets without loading everything into memory.
TerminusDB.Document.stream(config, type: "Person")
|> Stream.each(&IO.inspect/1)
|> Stream.run()

# 11. Clean up.
{:ok, _} = TerminusDB.Document.delete(config, id: "Person/Alice", author: "admin", message: "remove")
{:ok, _} = TerminusDB.Branch.delete(config, "feature")
{:ok, _} = TerminusDB.Database.delete(config, "mydb")
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
Licensed under the Apache License, Version 2.0.
See [LICENSE](LICENSE).
