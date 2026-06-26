# Changelog

All notable changes to `terminusdb_ex` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] — 2026-06-26

### Added — GraphQL (ADR-0009)

- `TerminusDB.GraphQL` module: `query/3`, `mutate/3`, `introspect/2` — thin
  HTTP wrapper for the `/api/graphql/{org}/{db}` endpoint.

### Added — Temporal / Allen WOQL (ADR-0010)

- `interval/3`, `interval_start_duration/3`, `interval_duration_end/3`,
  `interval_relation/5`, `interval_relation_typed/3`, `date_duration/3`,
  `day_after/2`, `day_before/2`, `weekday/2`, `weekday_sunday_start/2`,
  `iso_week/3`, `month_start_date/2`, `month_end_date/2`,
  `month_start_dates/3`, `month_end_dates/3`, `in_range/3`, `sequence/5`,
  `range_min/2`, `range_max/2`.

### Added — RDF list library (ADR-0011)

- `TerminusDB.WOQL.RDFList` module with 17 functions: `rdflist_list/2`,
  `rdflist_peek/2`, `rdflist_last/2`, `rdflist_nth0/3`, `rdflist_nth1/3`,
  `rdflist_member/2`, `rdflist_length/2`, `rdflist_pop/2`, `rdflist_push/3`,
  `rdflist_append/3`, `rdflist_clear/2`, `rdflist_empty/1`,
  `rdflist_is_empty/1`, `rdflist_slice/4`, `rdflist_insert/4`,
  `rdflist_drop/2`, `rdflist_swap/3`.

### Added — CSV / IO (ADR-0012)

- `WOQL.get/2`, `WOQL.put/3`, `WOQL.woql_as/1`, `WOQL.file/2`,
  `WOQL.remote/2`, `WOQL.post/2`.

### Added — Range queries

- `triple_slice/5`, `quad_slice/6`, `triple_slice_rev/5`,
  `quad_slice_rev/6`, `triple_next/4`, `quad_next/5`,
  `triple_previous/4`, `quad_previous/5`.

### Added — Client API gaps

- `TerminusDB.Prefix` module: `get/2`, `add/3`, `update/3`, `upsert/3`,
  `delete/2`, `all/2`.
- `Branch.squash/2`, `Branch.reset/3`, `Database.optimize/2`.
- `TerminusDB.Patch` struct: `from_json/1`, `to_json/1`, `update/1`,
  `before/1`, `copy/1`.
- `Diff.diff_object/2`, `Diff.diff_version/2`, `Diff.patch/2`,
  `Diff.patch_resource/2`, `Diff.apply/3`.
- `Commit.document_history/3`.
- `TerminusDB.Triples` module: `get/2`, `update/3`, `insert/3`.
- `WOQL.execute_stream/3` — streaming WOQL results.
- `TerminusDB.Remote` module: `clone/4`, `fetch/2`, `push/3`, `pull/3`.

### Added — Benchmarks

- `benchee` dev dependency.
- `TerminusDB.Benchmark` helper module.
- 5 benchmark suites in `bench/`.

### Added — Tutorials

- `guides/graphql-guide.md` — GraphQL queries, mutations, filters, pagination.
- `guides/temporal-allen-guide.md` — Intervals, Allen relations, calendar ops.
- `guides/csv-import-guide.md` — CSV reading/writing with WOQL.
- `guides/rdf-list-guide.md` — RDF list manipulation.

### Changed

- `rdflist_push/2` changed to `rdflist_push/3`: now takes a `new_head_var`
  parameter so callers can update their reference to the new list head.
- `Benchmark.seed_database/2` return type changed from `Config.t()` to
  `{Config.t(), String.t()}` so callers can clean up the database after
  benchmarking.
- `Patch.before/1` and `Patch.update/1` asymmetry documented: `before/1`
  preserves non-SwapValue fields for full state reconstruction; `update/1`
  only includes changed (SwapValue) fields.
- `WOQL.execute_stream/3` now uses lazy `Stream.map` instead of eager
  `Enum.map`, and safe `Jason.decode/1` instead of `Jason.decode!/1`.
- `GraphQL.query/3`, `GraphQL.mutate/3`, `GraphQL.introspect/2`, and all
  `Prefix.*` functions now return `{:error, %Error{reason: :config}}` when
  no database is scoped, instead of raising.

### Fixed — Review fixes (review-0.3.2.md)

- `rdflist_nth0`/`rdflist_nth1` variable-index path: fixed missing `v.dec`
  variable in localize map; added `eval(minus(...))` for decrement; unrolled
  recursion to avoid infinite Elixir recursion (C1).
- `rdflist_slice/4`: fixed silently ignored `end_val` parameter; rewrote
  with proper start/end bounds using cell navigation + collect (C2).
- `rdflist_swap/3`: fixed no-op implementation; added `rdflist_cell_at`
  helper and delete_triple/add_triple write operations for both cells (C3).
- `rdflist_drop/2`: fixed to operate on the cell at `position`, not the list
  head; position 0 deletes from head, position > 0 navigates to cell and
  relinks parent (H1).
- `rdflist_clear/2`: wrapped delete_triple calls inside `opt(and_([triple,
  delete]))` blocks to guard against unbound variables (M4).
- `encode_arithmetic/1`: added clause for non-variable binary strings (L2).
- `Benchmark.seed_database/2`: returns `{config, db_name}` for cleanup (L4).
- RDFList tests: added structural AST assertions verifying write operations
  (AddTriple/DeleteTriple) in swap/drop, dec variable in nth, Optional
  blocks in clear (L5).
- `encode_value/1`: added list encoding for `range_min`/`range_max`
  operands (uses `DataValue` wrapper with `list` field).

### Deferred to v0.3.3+

- GraphQL builder DSL.
- `graph/1` context setter.
- Data version headers (`last_data_version`/`get_data_version`).
- Gzip compression for large document inserts.
- Macro sugar layer (`TerminusDB.WOQL.Macros`).

### Deferred to v0.4+

- Access control (organizations, users, roles, capabilities).
- DataFrame (Explorer) integration.
- Ecto integration (`TerminusDB.Schema` macro).

## [0.3.1] — 2026-06-25

### Added — WOQL DSL v0.2 (ADR-0008)

Expanded the WOQL builder DSL from 7 operators to ~70, covering the core and
important-advanced vocabulary (Tier 1+2).

- **Logical combinators:** `not_/1`, `opt/1` (alias `optional/1`), `once/1`,
  `immediately/1`.
- **Query modifiers:** `distinct/2`, `limit/2`, `start/2`, `order_by/2` (accepts
  tuple-list or keyword-list form), `group_by/4`, `count/2`, `collect/3`, `star/0`,
  `all/0`.
- **Graph patterns:** `quad/4`, `added_triple/3`, `removed_triple/3`, `added_quad/4`,
  `removed_quad/4`, `add_triple/3`, `delete_triple/3`, `add_quad/4`, `delete_quad/4`,
  `update_triple/3`, `update_quad/4`.
- **Comparison:** `less/2`, `greater/2`, `gte/2`, `lte/2`, `like/3`.
- **Schema ops:** `isa/2`, `sub/2` (alias `subsumption/2`), `cast/3` (alias
  `typecast/3`).
- **Arithmetic:** `eval/2`, `plus/1`, `minus/1`, `times/1`, `divide/1`, `div/1`,
  `exp/2`, `floor/1`, `sum/2`.
- **String ops:** `concat/2`, `join/3`, `substr/5` (alias `substring/5`), `trim/2`,
  `upper/2`, `lower/2`, `pad/4`, `split/3`, `length/2`, `regexp/3`.
- **List/Set/Dict:** `dot/3`, `member/2`, `slice/4`, `set_difference/3`,
  `set_intersection/3`, `set_union/3`, `set_member/2`, `list_to_set/2`.
- **Path/navigation:** `path/3..4` with a dual-mode DSL — string-compiled parser
  (`path("v:S", "<friend*{1,3}", "v:O")`) and structured builders (`path_star/1`,
  `path_plus/1`, `path_times/3`, `path_seq/1`, `path_or/1`, `path_inverse/1`,
  `path_pred/1`, `path_any/0`).
- **ID generation:** `unique/3`, `idgen/3` (alias `idgenerator/3`), `idgen_random/2`
  (alias `random_idgen/2`).
- **Documents:** `insert_document/2`, `update_document/2` (optional identifier),
  `delete_document/1`.
- **Graph context:** `using/2`, `from/2`, `into/2`, `comment/2`.
- **Graph meta:** `size/2`, `triple_count/2`.
- **Literal/value helpers:** `var/1`, `iri/1`, `string/1`, `boolean/1`, `datetime/1`,
  `date/1`, `literal/2`, `true_/0`.

### Changed

- **4-wrapper value model:** the JSON-LD encoder now uses `NodeValue`, `Value`,
  `DataValue`, and `ArithmeticValue` (matching the Python/JS clients), replacing the
  2-wrapper `NodeValue`/`DataValue` model from v0.3.
- **`triple/3` object encoding:** constant string objects now encode as `Value` with
  `xsd:string` data (literals), matching Python. Previously they encoded as `NodeValue`
  with `node` (IRIs). **Migration:** pass `iri("...")` explicitly when an IRI object
  is intended.
- **`read_document/2` field ordering:** the document id is now under `"identifier"`
  (NodeValue) and the output variable under `"document"` (Value), matching the
  canonical wire format. Previously these were swapped.
- **`eq/2` operands:** now wrapped in `Value` (was `DataValue`), matching Python.
- **`type_of/2`:** `value` uses `Value`, `type` uses `Value` (was `NodeValue`).
- **`float` literals:** encode as `xsd:decimal` in the query builder (matches Python's
  wire output).
- Module split: `woql.ex` now delegates encoding/decoding/path/literal helpers to
  internal sub-modules (Encoder, Decoder, Path, Literal).
- Version bumped to 0.3.1; `source_ref` updated for HexDocs.

### Fixed

- `read_document/2`: field ordering now matches the canonical WOQL JSON-LD wire format
  (was reversed, causing incorrect encoding).
- Path parser: now raises `ArgumentError` on empty or malformed patterns instead
  of crashing with `MatchError`.
- Path quantifier `{n}` now correctly produces `PathTimes` with `to = n` (exactly n),
  distinguishing it from `{n,}` (at least n, unbounded).
- `WOQL.execute/3`: now returns `{:error, %Error{reason: :config}}` when no database
  is scoped in config, instead of raising. Added `:config` to `TerminusDB.Error`
  reason types.
- `insert_document/2` and `update_document/2`: document maps are now encoded as
  `DictionaryTemplate` with `FieldValuePair` entries (matching the JS `doc()`
  wrapper), fixing "Not well formed WOQL JSON-LD" errors on TerminusDB 12.

### Deferred to v0.3.2+

- Temporal / Allen interval algebra family (19 operators).
- RDF list library (`WOQLLibrary.rdflist_*`, 17 macros).
- CSV/IO (`get`, `put`, `woql_as`, `file`, `remote`, `post`).
- `graph/1` context setter.
- Macro sugar layer (`TerminusDB.WOQL.Macros`).
- Range query family (`triple_slice*`, `triple_next`, `triple_previous`).

## [0.3.0] — 2026-06-25

### Added — versioned query workflows and WOQL DSL

- **`TerminusDB.Commit`**: commit history and inspection — `log/2`, `history/2`,
  `get/3` (plus `!/` variants). Branch-aware with pagination (`:start`, `:limit`).
- **`TerminusDB.Diff`**: document and branch-level diff — `compare/2` /
  `compare!/2`. Supports `before`/`after` document values or branch/commit refs,
  plus `:keep` for field preservation.
- **`TerminusDB.Merge`**: branch merge (rebase) — `merge/2` (plus
  `!/` variant). Uses the `/api/rebase` endpoint with `author`/`rebase_from`
  body.
- **`TerminusDB.WOQL`**: functional builder DSL (ADR-0002) — `triple/3`,
  `and_/1`, `or_/1`, `eq/2`, `select/2`, `read_document/2`, `type_of/2`.
  Serializes to the correct WOQL JSON-LD wire format (`NodeValue`/`DataValue`
  wrappers, short type names like `"Triple"`, `"Equals"`). `to_jsonld/1` and
  `from_jsonld/1` are round-trip tested. `execute/3` / `execute!/3` POST to
  `/api/woql/:org/:db/:repo/branch/:branch` with `commit_info` support.
- Telemetry areas `:commit` and `:woql` added to `TerminusDB.Telemetry`.
- Integration tests for commit log/history, diff, merge (branch divergence +
  rebase), and WOQL execution against a live TerminusDB 12.
- Overview guide updated with Commit, Diff, Merge, and WOQL DSL sections.
- 58 new unit tests (Commit, Diff, Merge, WOQL including round-trips).

### Fixed (discovered via integration testing against TerminusDB 12)

- `Schema.frame/3`: class name is now a `?type=` query param, not a path
  segment (server returns 404 for path-appended class names).
- `Branch.exists?/3`: rewrote to check `db/:org/:db?branches=true` branch list
  (the `/branch` endpoint only supports POST/DELETE, not HEAD or GET).
- `Document.query/3`: now always sends `as_list=true` (server returns
  concatenated JSON by default, which crashes Req's JSON decoder).
- `Commit.history/2`: uses the `/log` endpoint (the `/history` endpoint requires
  a commit ID and cannot list without one).
- `WOQL.eq/2`: type is `"Equals"` not `"Eq"`; literals are wrapped in
  `DataValue` with xsd type annotations.
- `Merge.merge/2`: uses `/rebase` with `author`/`rebase_from` body (not
  `/pull` with `remote`/`remote_branch`, which causes 500 on local merges).
- `WOQL.execute/3`: now includes `:repo`/`:branch` in the WOQL path
  (`woql/:org/:db/:repo/branch/:branch`).

### Changed

- Version bumped to 0.3.0; `source_ref` updated for HexDocs.
- TerminusDB 12 compatibility verified (v12.0.5): range queries, ISO8601 date
  predicates, WOQL `comment`/`collect` predicates, cardinality on `Set`,
  `@metadata`/`@context` JSON handling, diff+streaming in history endpoint.

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
[0.3.0]: https://github.com/thanos/terminusdb-client-elixir/releases/tag/v0.3.0
[0.3.1]: https://github.com/thanos/terminusdb-client-elixir/releases/tag/v0.3.1
