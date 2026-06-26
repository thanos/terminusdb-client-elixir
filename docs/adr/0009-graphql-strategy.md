# ADR-0009: GraphQL thin wrapper strategy

Date: 2026-06-25
Status: Accepted (implementation in v0.3.2)

## Context

TerminusDB 12 exposes a GraphQL endpoint at `/api/graphql/{org}/{db}` with
auto-generated schema (from the database's document schema), queries (filter,
limit, offset, orderBy, backlinks, path queries, count), and mutations
(insert/replace/delete documents with optional commit info). GraphiQL is
available at `/api/graphiql/{org}/{db}`.

Neither the Python nor the Elixir client currently implements GraphQL support.
The v0.3.2 release adds it as a net-new feature.

## Decision

Implement a **thin HTTP wrapper** — `TerminusDB.GraphQL` module with three
functions:

- `query/3` — sends a raw GraphQL query string via POST, returns
  `{:ok, %{data: data, errors: errors}}` or `{:error, %Error{}}`.
- `mutate/3` — same as `query/3` but conventionally used for mutations.
- `introspect/2` — sends a `__schema` introspection query, returns
  `{:ok, schema_map}`.

The user writes GraphQL query strings directly. No programmatic query builder
DSL is provided in v0.3.2.

### Rationale

- GraphQL is a query language with its own syntax; wrapping it in a builder DSL
  adds complexity without much value — the user still needs to understand
  GraphQL schema/types.
- A thin wrapper gets GraphQL working quickly and lets users leverage the
  GraphiQL browser for schema exploration.
- A builder DSL can be layered on top later (v0.3.3+) once usage patterns
  emerge.

### Endpoint

```
POST /api/graphql/{org}/{db}
Content-Type: application/json
Authorization: Basic ... (or Token ...)

{"query": "...", "variables": {...}}
```

### Telemetry

`[:terminusdb, :graphql, :start|:stop]` — consistent with all other operations.

## Consequences

- Users must write GraphQL strings (no compile-time validation).
- No schema caching or introspection-based type checking.
- Error handling: GraphQL errors (in the `errors` field) are returned as
  `{:ok, %{data: _, errors: _}}`, while HTTP/transport errors are
  `{:error, %Error{}}`.

## Alternatives considered

1. **Programmatic query builder DSL** — rejected for v0.3.2 (too opinionated,
   large surface area, can be added later).
2. **Absinthe integration** — rejected (adds a heavy runtime dep for something
   TerminusDB already provides server-side).
3. **Code generation from introspection** — rejected (complex, needs build
   step).
