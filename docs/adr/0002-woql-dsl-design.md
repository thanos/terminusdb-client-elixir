# ADR-0002: Functional builder DSL for WOQL

Date: 2026-06-23
Status: Accepted (design only; implementation in v0.2)

## Context

WOQL is a composable query language compiled to JSON-LD. The JS/Python clients offer a
fluent style (`q.triple(...).triple(...)`) and a functional style (`and(triple(...), ...)`).
The TerminusDB docs explicitly recommend the functional style to avoid ambiguity in
conjunction with sub-clauses (`opt`, `not`).

Elixir options: a macro DSL, a builder struct DSL, or a plain functional DSL.

## Decision

Implement a **plain functional builder DSL** returning an opaque `TerminusDB.WOQL.Query`
struct that compiles to JSON-LD.

```elixir
import TerminusDB.WOQL

query =
  and_([
    triple("v:Person", "rdf:type", "Person"),
    triple("v:Person", "name", "v:Name")
  ])

Client.query(config, query)
```

- Functions (`triple/3`, `and_/1`, `select/2`, `opt/1`, `not/1`, `eq/2`, `path/3`, …)
  return `%WOQL.Query{}` and compose by nesting — mirroring the recommended functional
  WOQL style.
- Variable literals are plain strings following the `v:Name` convention (matches WOQL.js).
- `WOQL.to_jsonld/1` compiles to the wire format; `WOQL.from_jsonld/1` round-trips.

## Consequences

- **+** No macros → no compile-time complexity, works in any context (incl. Livebook),
  trivially composable at runtime.
- **+** Matches TerminusDB's recommended functional style and is unambiguous for `opt`/`not`.
- **+** The `WOQL.Query` struct is the natural target for ExDatalog compilation (ADR-0004).
- **−** Less "magic" than a macro DSL; users write `and_([...])` instead of `and do ... end`.
  Acceptable: clarity wins, and a macro sugar layer can be added later without breaking the
  functional core.

## Alternatives

- **Macro DSL** (`woql do triple(...) end`) — prettier but introduces compile-time
  semantics, import edge cases, and harder runtime composition. Rejected as the core;
  may be layered on later as `TerminusDB.WOQL.Macros`.
- **Fluent/builder struct** (`WOQL.new() |> WOQL.triple(...) |> WOQL.triple(...)`) —
  obscures sub-clause nesting and reintroduces the ambiguity the docs warn about. Rejected.
