# ADR-0005: Telemetry strategy

Date: 2026-06-23
Status: Accepted

## Context

A production client must be observable. The Elixir standard for instrumentation is the
`:telemetry` library, used by Phoenix, Ecto, Req, and Livebook. We need a uniform event
scheme covering database, document, query, branch, merge, and diff operations.

## Decision

Emit `:telemetry` events from `TerminusDB.Client.request/2` (the single wire module) and
from higher-level API modules where domain-specific metadata adds value.

### Event names

Every operation emits a `start` and a `stop` event:

```
[:terminusdb, <area>, :start]
[:terminusdb, <area>, :stop]
```

`<area>` ∈ `:database, :document, :query, :branch, :merge, :diff, :connection`.

### Measurements

- `start`: `%{system_time: System.monotonic_time()}`
- `stop`:  `%{duration: native_time, system_time: System.monotonic_time()}` (duration =
  stop − start; emit in `:native` unit, let handlers convert).

### Metadata

- `start`: `%{config: map, method: atom, path: String.t(), area: atom, ...}`
- `stop`:  `%{config: map, method: atom, path: String.t(), area: atom, status: pos_integer | nil, error: Exception.t | nil, ...}`

`config` is redacted (auth stripped) before being placed in metadata.

### Exceptions

On `{:error, error}`, `stop` carries `error: %TerminusDB.Error{}` and `duration` still
emitted. A `[:terminusdb, <area>, :exception]` event is **not** added — `stop` with an
error is sufficient and matches the Phoenix/Ecto convention.

## Consequences

- **+** Uniform, predictable scheme; users attach handlers with `:telemetry.attach/4`.
- **+** Centralizing emission in `Client.request/4` guarantees no operation is missed.
- **−** Redaction discipline is required so credentials never leak into metadata.

## Alternatives

- **Per-operation custom events** — inconsistent, easy to forget. Rejected.
- **Logger-based instrumentation** — not structured/low-overhead by default. Rejected as
  primary; Logger debug entries may complement telemetry.
