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

## Installation

Add `terminusdb_client` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:terminusdb_client, "~> 0.3.3"}
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

## GraphQL

TerminusDB auto-generates a GraphQL endpoint from your document schema.
Query and mutate using raw GraphQL strings:

```elixir
# Query all Person documents
{:ok, result} = TerminusDB.GraphQL.query(config, "{ Person { name age } }")
# => {:ok, %{data: %{"Person" => [%{"name" => "Alice", "age" => 30}]}, errors: nil}}

# Insert via mutation
{:ok, _} = TerminusDB.GraphQL.mutate(config, "mutation { _insertDocuments(json: \"...\") }")

# Introspect the auto-generated schema
{:ok, schema} = TerminusDB.GraphQL.introspect(config)
```

## WOQL queries

The WOQL DSL provides ~100 composable operators for graph queries:

```elixir
import TerminusDB.WOQL

# Query with select, triple pattern, and limit
{:ok, result} =
  WOQL.execute(config,
    select(["v:Name", "v:Age"],
      limit(10,
        and_([
          triple("v:Person", "name", "v:Name"),
          triple("v:Person", "age", "v:Age"),
          triple("v:Person", "rdf:type", iri("@schema:Person"))
        ])
      )
    )
  )

# Stream WOQL results (lazy, constant memory)
{:ok, stream} = WOQL.execute_stream(config, query)
Enum.to_list(stream)
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
(`<area>` is `:database`, `:document`, `:query`, `:branch`, `:merge`, `:diff`,
`:commit`, `:woql`, `:graphql`, `:prefix`, `:triples`, `:remote`, or
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

## Roadmap

| Milestone | Scope | Status |
| --- | --- | --- |
| **v0.1.0** | Config, Error, Telemetry, Client, Database API | Done |
| **v0.2.0** | Document CRUD + streaming, Schema, Branch, guides | Done |
| **v0.3.0** | Commit, Diff, Merge, WOQL DSL v0.1, TerminusDB 12 compat | Done |
| **v0.3.1** | WOQL DSL v0.2 (~70 operators, 4-wrapper value model, path DSL) | Done |
| **v0.3.2** | GraphQL, temporal/Allen (19 ops), RDF list (17 fns), CSV/IO (6 ops), range queries (8 ops), prefix mgmt, patch/apply, triples, remote, WOQL streaming, benchmarks, tutorials | Done |
| **v0.3.3** | Bug fixes: document query filtering, branch-scoped paths, Schema.all @context filtering, Livebook script repair | Done |
| **v0.4.0** | Ecto schema definition (`TerminusDB.Schema` macro), access control (RBAC), Explorer DataFrame integration | Pending |
| **v0.5.0** | ExDatalog bridge (`TerminusDB.Datalog`) | Pending |

### Parity with the Python client

Full gap analysis: see `baoulo/reviews/gap-analysis.md` in the repository.

| Area | Elixir | Python | Notes |
| --- | --- | --- | --- |
| WOQL operators | 108 | 108 | Full parity |
| RDF list library | 17 fns | 17 fns | Full parity |
| GraphQL | 3 methods | None | Elixir advantage |
| Telemetry | Every op | None | Elixir advantage |
| Schema definition | Read-only frames | Full `DocumentTemplate` metaclass | v0.4 (Ecto) |
| DataFrame | None | pandas `WOQLDataFrame` | v0.4+ (Explorer) |
| Access control | None | 16 methods (orgs/users/roles) | v0.4+ |
| Property tests | 9 (StreamData) | None | Elixir advantage |
| ADRs | 13 | None | Elixir advantage |

See `docs/adr/` for architectural decisions behind each milestone.

## License
Licensed under the Apache License, Version 2.0.
See [LICENSE](LICENSE).
