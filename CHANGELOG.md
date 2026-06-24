# Changelog

All notable changes to `terminusdb_ex` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] — 2026-06-24

### Added — document, schema, branch, and streaming APIs

- **`TerminusDB.Document`**: document CRUD and query API — `insert/3`, `get/2`,
  `query/3`, `replace/3`, `delete/2`, `stream/2` (plus `!/` variants). Supports
  `graph_type` (instance/schema), `author`/`message` commit metadata,
  `full_replace`, `raw_json`, `create`, `nuke`, pagination (`skip`/`count`),
  `as_list`, `unfold`, `minimized`, `compress_ids`. The `stream/2` function
  returns a lazy `Enumerable` of decoded documents with constant memory via
  Req's `into: :self` and the concatenated-JSON splitter.
- **`TerminusDB.Schema`**: schema frame API — `frame/3`, `all/2` (plus `!/`
  variants). Supports `compress_ids` and `expand_abstract` params (including
  explicit `false`).
- **`TerminusDB.Branch`**: branch management API — `create/3`, `delete/3`,
  `exists?/3` (plus `!/` variants). Supports `:from`, `:organization`, `:repo`
  overrides in both the path and the origin body.
- **`TerminusDB.Streaming`**: incremental concatenated-JSON decoder for streaming
  document responses (ADR-0007). `split_concatenated/1` (bracket/depth-aware
  splitter respecting string literals, escapes, and cross-chunk boundaries) and
  `document_stream/2` (with a configurable receive timeout).
- Internal shared helper for building query parameters (`Client.Params`),
  parameters, distinguishing flag params (omit when false) from tri-state bool
  params (send explicit false to override server defaults).
- **`TerminusDB.Client.resource_path/2`**: now resolves org/db from config and
  opts, used by all per-module path builders.
- Integration tests for Document (insert/query/stream/delete), Schema (frame
  retrieval), and Branch (create/exists?/delete) against a Dockerized TerminusDB.
- 54 new unit tests covering Document, Schema, Branch, and Streaming.
- Guides: `guides/introduction.md` (TerminusDB concepts), `guides/migrating-from-sql.md`
  (SQL-to-TerminusDB migration by example), `guides/overview.md` (feature walkthrough),
  `guides/terminusdb_ex_livebook.livemd` (full Livebook demo).
- Hermetic doctest examples on every public function (27 doctests total).

### Fixed

- `Document.get/2`: `unfold`, `minimized`, `compress_ids`, and `as_list` set to
  `false` are now sent to the server (previously silently dropped, so the
  server's `true` defaults always won).
- `Document.stream/2`: raises `TerminusDB.Error` on client errors instead of
  `MatchError`.
- `Branch.create/3`: `:organization` and `:repo` overrides are now reflected in
  the origin body, not just the path.
- `Streaming.document_stream/2`: no longer hangs if the server never sends
  `:done` — a receive timeout halts the stream.
- `Streaming.split_concatenated/1`: handles a lone trailing `\` at a chunk
  boundary inside a string (retains it for the next chunk).
- Flaky telemetry test fixed (unique-path filtered `refute_receive`).
- All documentation examples corrected: `{:ok, _} = delete(...)` instead of
  `:ok = delete(...)`.

### Changed

- `Client.resource_path/2` signature changed from `(org, db)` to `(config, opts)`.
- Version bumped to 0.2.0; `source_ref` updated for HexDocs.
- `.sobelow-conf` ignores `SQL.Query` false positive on `Document.query/3`.

## [0.1.0] — 2026-06-23

### Added — foundation (v0.1)

- **`TerminusDB.Config`**: immutable, NimbleOptions-validated connection/resource
  context with scoping helpers (`with_database/2`, `with_branch/2`,
  `with_organization/2`, `with_repo/2`, `with_ref/2`), Basic + Bearer auth, and
  `redact/1` for safe logging.
- **`TerminusDB.Error`**: typed error struct + exception with `:reason`
  (`:transport`/`:http`/`:api`/`:decode`), structured `api:*` parsing, and
  constructors `transport/1`, `http/2`, `api/2`, `decode/2`.
- **`TerminusDB.Client`**: the single HTTP wire module (Req-based). `request/4`,
  `request!/4`, `request_response/4`; centralizes auth, headers, JSON, error
  mapping, and telemetry. Supports the Req fake `adapter:` for hermetic tests.
- **`TerminusDB.Database`**: database management API — `create/3`, `delete/3`,
  `info/3`, `list/2`, `exists?/3`, `update/3` (plus `!/` variants).
- **`TerminusDB.Telemetry`**: `[:terminusdb, <area>, :start|:stop]` events with
  measurements and redacted metadata.
- Telemetry on every operation; retry disabled for predictable behavior.

### Tooling & infrastructure

- Dependencies: `req`, `jason`, `nimble_options`, `telemetry`.
- Dev/test: `ex_doc`, `credo`, `dialyxir`, `sobelow`, `excoveralls`, `stream_data`.
- CI: GitHub Actions (format, compile, credo, sobelow, dialyzer, tests + coverage,
  docs) on Elixir 1.18 / 1.19 / 1.20.
- Release workflow: tagged publishes to Hex.pm with a full quality gate.
- `docker-compose.yml` for local integration tests.
- Strict `.credo.exs`, formatter config (line length 98), dialyzer PLT caching.

### Documentation

- `ARCHITECTURE.md`: review summary, architecture option analysis, high-level
  design.
- 7 ADRs (`docs/adr/`): Req, WOQL DSL, Ecto, ExDatalog, Telemetry, Testing,
  Streaming.
- `AGENTS.md`: operating guide, commands, conventions, milestone roadmap.
- `LICENSE` (Apache-2.0), `CHANGELOG.md`, `README.md`.

### Tests

- 79 unit tests + 18 doctests, all hermetic (fake Req adapter). 100% `lib/`
  coverage.
- Integration tests (`test/integration/`) against a Dockerized TerminusDB; run
  manually via `mix test --only integration`.

[0.1.0]: https://github.com/thanos/terminusdb-client-elixir/releases/tag/v0.1.0
[0.2.0]: https://github.com/thanos/terminusdb-client-elixir/releases/tag/v0.2.0
