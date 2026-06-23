# ADR-0006: Testing strategy

Date: 2026-06-23
Status: Accepted

## Context

The prompt requires unit, integration, regression, property, and documentation tests, with
CI running against Dockerized TerminusDB and coverage ≥ 80% (minimum 70%).

## Decision

Adopt a layered strategy using `ExUnit` + `ExCoveralls` + `StreamData`:

1. **Unit tests** (`test/terminusdb_ex/*_test.exs`) — fast, hermetic, no network. The HTTP
   layer is stubbed with Req's fake `adapter: fn request -> {request, response} end`,
   injected via a test-only `TerminusDB.Config` field. Tests assert both *requests*
   (method/path/params/body/auth) and *responses* (decoded bodies, errors, telemetry).

2. **Property tests** (`test/terminusdb_ex/property/*_test.exs`) — `StreamData` generators
   for configs, document maps, and WOQL ASTs. Assert round-trips (e.g.
   `WOQL.from_jsonld(WOQL.to_jsonld(q)) == q`) and invariants (e.g. error struct shape).

3. **Doctests** — every public function with an example gets a `doctest`. Kept hermetic
   by using the fake adapter or pure functions only.

4. **Integration tests** (`test/integration/*_test.exs`, `@moduletag :integration`) — run
   against a real TerminusDB in Docker. Skipped by default (`--only integration`).
   A `docker-compose.yml` + helper script start/stop the server; CI runs these in a job.

5. **Regression tests** (`test/regression/`) — pinned scenarios for reported bugs.

### Coverage

`ExCoveralls` with `test_coverage: [tool: ExCoveralls]` and `preferred_cli_env` for
`coveralls`/`credo`/`dialyzer`/`sobelow`. Target 80%, enforced floor 70% via CI check.

## Consequences

- **+** Unit tests run in milliseconds everywhere (no Docker needed for the inner loop).
- **+** Property tests catch serialization/round-trip bugs early.
- **+** Integration tests validate real-wire compatibility without slowing local dev.
- **−** Two test modes require discipline (tags + `--only`). Mitigated by CI matrix.

## Alternatives

- **Bypass** for HTTP stubbing — workable, but Req's fake adapter is dependency-free and
  lets us assert the *exact* outgoing request struct. Preferred.
- **Mox** — no behaviour to mock yet (Client is a module of functions); revisit if Client
  becomes a GenServer/behaviour.
