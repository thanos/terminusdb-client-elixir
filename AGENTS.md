# AGENTS.md

Operating guide for AI agents (and humans) working on `terminusdb_ex`.
Read this before making changes.

## Project

`terminusdb_ex` is an idiomatic Elixir client for TerminusDB (document graph DB
with version control). Module namespace is `TerminusDB`; files live in
`lib/terminus_db/*.ex`. App name: `terminusdb_client`.

The full design lives in `ARCHITECTURE.md` and `docs/adr/`. The source spec is
`baoulo/prompts/prompt-0.1.0.md` (do not edit it).

## Commands

Always run these from the project root. Run the full quality gate before declaring
a task done:

```bash
mix deps.get                              # install deps
mix compile --warnings-as-errors          # compile (fail on warnings)
mix format                                # auto-format
mix format --check-formatted              # verify formatting
mix credo --strict                        # static analysis
mix sobelow --exit Low                   # security scan (exits non-zero on findings)
mix test                                  # unit + doctests (hermetic, no Docker)
mix coveralls                             # coverage (enforced minimum 80% via coveralls.json)
mix dialyzer                              # type checks (first run is slow; PLT cached)
mix docs                                  # build docs
mix quality                               # format+credo+sobelow+dialyzer alias
mix verify                               # full quality gate + tests + docs
```

Integration tests (require a live TerminusDB):

```bash
docker compose up -d                      # start TerminusDB on :6363
until curl -sf http://localhost:6363/api/ok >/dev/null 2>&1; do sleep 1; done
mix test --only integration               # run integration suite
docker compose down                       # teardown
```

### Verification checklist (run after every change)

1. `mix format --check-formatted`
2. `mix compile --warnings-as-errors`
3. `mix credo --strict`
4. `mix test` (must be 0 failures)
5. `mix coveralls` (must be ≥ 80%)
6. `mix dialyzer` (must be 0 errors)

If you cannot find a command, ask the user and then add it here.

## Conventions

### Architecture (non-negotiable)

- **`TerminusDB.Client` is the only module that touches the wire.** All API
  modules (`Database`, `Document`, …) compose a request and call
  `TerminusDB.Client.request/4`. Never call `Req` directly outside `Client`.
- **Immutable config.** `TerminusDB.Config` is data. Scope with `with_database/2`,
  `with_branch/2`, etc. — never mutate. No `Agent`/process state for connection.
- **Tuple results.** Public functions return `{:ok, _} | {:error, %TerminusDB.Error{}}`.
  Provide a `!/`-suffixed variant that raises. Predicates (`exists?/3`) return
  booleans and may raise on unexpected errors.
- **Telemetry on every operation.** Pass `area: :<area>` to `Client.request/4`;
  `Client` emits `[:terminusdb, <area>, :start|:stop]`. Redact config via
  `TerminusDB.Config.redact/1` before it enters metadata.
- **String keys.** TerminusDB bodies use JSON keys like `@type`, `api:status`.
  Jason defaults to `:strings` — do not decode to atoms (atom-exhaustion safety).
  Match on string keys in error/response handling.

### Style

- No comments unless asked. Code should be self-documenting.
- Line length 98 (enforced by formatter + credo).
- Every public function gets `@moduledoc`/`@doc` + `@spec`.
- Every public function with an example gets a doctest. Doctests must be hermetic
  (use the Req fake `adapter:` — never hit the network in doctests/unit tests).
- `@enforce_keys` for required struct fields. Validate options with NimbleOptions.
- File naming: `TerminusDB.Foo` → `lib/terminus_db/foo.ex`.

### Testing

- **Unit tests** (`test/terminus_db/*_test.exs`): hermetic, fast, no network.
  Stub HTTP with `Config.new(adapter: fn req -> {req, Req.Response.new(...)} end)`.
  Assert both the outgoing request (method, URL, body, headers, params) and the
  returned result/error.
- **Doctests**: hermetic only.
- **Property tests** (`test/terminus_db/property/*_test.exs`): use `StreamData`
  for round-trips and invariants.
- **Integration tests** (`test/integration/*_test.exs`): tag `@moduletag
  :integration`; run only with `--only integration` against Dockerized TerminusDB.
- **Telemetry-in-tests pitfall**: `:telemetry` handlers are global. When asserting
  on events from concurrent tests, use a **unique request path** and filter
  `assert_receive` by `meta.path` to avoid cross-test event leakage.
- Retry is disabled in `Client` (`retry: false`) — keep it that way for
  predictable tests and behavior.

## Dependency policy

Minimize deps. Runtime (v0.2): `req`, `jason`, `nimble_options`, `telemetry`.
Ecto and ExDatalog will be **optional** dependencies, gated by compile flags,
when their integrations land (v0.3/v0.4). Do not add a runtime dep without an
ADR justifying it.

## Milestone roadmap

| Milestone | Scope | Status |
| --- | --- | --- |
| **v0.1 (foundation)** | Config, Error, Telemetry, Client (Req), Database API, unit tests, CI, ADRs, ARCHITECTURE, AGENTS | **Done** |
| **v0.2 (APIs)** | Document, Schema, Branch, Streaming, Document.query/stream, guides, Livebook | **Done** |
| v0.2.1+ | Commit, Diff, Merge, GraphQL, WOQL functional DSL, benchmarks | Pending |
| v0.3 (Ecto) | `use TerminusDB.Schema` macro, schema generation, optional `:ecto` dep; research full `Ecto.Adapter` feasibility | Pending |
| v0.4 (ExDatalog) | `TerminusDB.Datalog` bridge (`to_woql`, `to_jsonld`, `from_triples`), optional `:datalog` dep | Pending |
| Release | CHANGELOG, release notes, migration guide, Hex.pm review, final review | Pending |

## Key references

- TerminusDB docs: https://terminusdb.org/docs/
- TerminusDB OpenAPI: https://github.com/terminusdb/openapi-specs (raw `terminusdb.yaml`)
- Python client (reference): https://github.com/terminusdb/terminusdb-client-python
- Req: https://hexdocs.pm/req/Req.html
- Design decisions: `docs/adr/` (Req, WOQL DSL, Ecto, ExDatalog, Telemetry, Testing, Streaming)

## Do NOT

- Do not commit secrets or `mix.lock` credentials.
- Do not add `mix.lock` removal; keep `mix.lock` for reproducible CI.
- Do not raise on expected API errors — return `{:error, %TerminusDB.Error{}}`.
- Do not decode JSON to atoms.
- Do not run integration tests in the default `mix test` run.
- Do not commit changes unless the user explicitly asks.
