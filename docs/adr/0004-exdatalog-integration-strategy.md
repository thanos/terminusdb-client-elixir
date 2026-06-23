# ADR-0004: ExDatalog ↔ WOQL bridge

Date: 2026-06-23
Status: Accepted (implementation in v0.4)

## Context

WOQL is itself a datalog engine (Prolog-backed, JSON-LD serialized). ExDatalog is an
Elixir-native Datalog. The goal is to let users write recursive Datalog rules and either
(a) compile them to WOQL for server-side evaluation, or (b) load TerminusDB query results
(triples) into ExDatalog for in-process evaluation.

## Decision

Implement a `TerminusDB.Datalog` bridge with three transformations:

- `TerminusDB.Datalog.to_woql/1` — compile a Datalog program (facts + rules) into a
  `TerminusDB.WOQL.Query` (ADR-0002) for server-side execution. Target the *non-recursive
  + stratified-recursion* subset that WOQL's `path()` and `limit`/`order` can express;
  document the supported fragment precisely.
- `TerminusDB.Datalog.to_jsonld/1` — emit the JSON-LD triple representation of facts.
- `TerminusDB.Datalog.from_triples/1` — load WOQL/triple query results into an ExDatalog
  database for local evaluation (enables recursion WOQL cannot push down).

```elixir
# Conceptual target
ancestor(X, Y) :- parent(X, Y).
ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
```

## Consequences

- **+** Recursion that is awkward in WOQL can run locally via ExDatalog; non-recursive
  rules push down to the server for set-at-a-time evaluation.
- **+** `to_woql` reuses the ADR-0002 DSL's compiler, avoiding a second JSON-LD emitter.
- **−** Not all Datalog compiles cleanly to WOQL (negation, aggregation, constraints).
  The bridge will document a **supported subset** and fall back to `from_triples` +
  local evaluation for the rest.
- **−** Adds ExDatalog as an optional dependency, gated behind a `:datalog` compile flag.

## Alternatives

- **WOQL only, no Datalog** — loses the educational/reasoning story that differentiates the
  library. Rejected.
- **Local Datalog only (no `to_woql`)** — forgoes server-side evaluation and large datasets.
  Rejected; the bidirectional bridge is the value proposition.
