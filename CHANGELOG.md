# Changelog

All notable changes to `terminusdb_ex` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
