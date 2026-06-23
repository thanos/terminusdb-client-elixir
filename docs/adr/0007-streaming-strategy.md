# ADR-0007: Streaming strategy

Date: 2026-06-23
Status: Accepted

## Context

TerminusDB document GET returns concatenated JSON or a JSON array, and query results can
be large. Elixir users expect `Stream`/`Enumerable` APIs to process such data lazily and
with backpressure, not a fully decoded list in memory.

## Decision

Build streaming on Req's response-body streaming, exposed as `Enumerable`:

- `TerminusDB.Document.stream/2` returns a `Stream` of decoded document maps, backed by
  Req's `into: fn {:data, chunk}, {req, resp} -> ... end` callback that incrementally
  parses the concatenated-JSON / JSON-array response.
- `TerminusDB.WOQL.stream/2` (v0.2) streams query result bindings similarly.
- A central `TerminusDB.Streaming` helper owns the incremental JSON decoder glue
  (newline/concatenated-JSON aware) so document and query streams share one implementation.

## Consequences

- **+** Constant memory for large result sets; integrates with `Enum`/`Stream` pipelines.
- **+** No extra dependency: Req + Jason suffice (Jason's incremental `decode!` on chunks
  via a small accumulator).
- **−** Concatenated JSON (not newline-delimited) needs a bracket/depth-aware splitter;
  the `Streaming` helper handles this and is unit-tested with property tests.

## Alternatives

- **Eager list return only** — simple but unbounded memory. Rejected as the sole option;
  eager variants remain for small, known-size calls.
- **GenStage/Flow** — overkill for a client; `Enumerable` is the idiomatic, composable fit.
