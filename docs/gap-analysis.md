# Gap Analysis: `terminusdb_ex` v0.3.2 vs `terminusdb-client-python`

Date: 2026-06-26
Elixir client version: 0.3.2
Python client tree SHA: `f972cefdee5d0ec5e22729df2468a31c17f08c86` (main)
TerminusDB server target: 12.0.6

---

## 1. Executive Summary

This analysis compares the Elixir `terminusdb_ex` client (v0.3.2) against the
Python `terminusdb-client-python` client (main branch, SHA `f972cefd`, unchanged
since 2026-06-25).

**Methodology:** Every public module, function, and WOQL operator was extracted
from both codebases. The Python client's `woql_query.py` (5,212 lines),
`Client.py` (3,407 lines), `schema/schema.py` (1,000+ lines),
`woqldataframe/woqlDataframe.py`, and `__init__.py` were analyzed. The Elixir
client's 26 `.ex` files across 20 public modules were inventoried.

**Current state after v0.3.2:**

- **WOQL operators:** 108 at parity (all Python WOQL operators implemented),
  3 utility gaps (`graph/1`, `load_vocabulary/1`, `localize/1` as public API).
  Elixir has structured path builders that Python lacks.
- **Client API:** 50+ methods at parity. 3 remaining gaps (data version headers,
  gzip compression, `load_vocabulary`). 16 access-control methods deferred.
- **GraphQL:** Elixir has it (`TerminusDB.GraphQL`), Python does not. Net-new
  advantage.
- **Schema definition system:** Python has a full `WOQLSchema` / `DocumentTemplate`
  metaclass system (64 classes/functions) for defining schemas as Python classes.
  Elixir has `Schema.frame/3` (read-only) but no schema definition macro -
  planned for v0.4 (`TerminusDB.Schema` macro via Ecto).
- **DataFrame:** Python has `WOQLDataFrame` (pandas integration). Elixir has no
  equivalent - Explorer/Nx integration planned for v0.4+.

---

## 2. WOQL Operator Coverage

### 2.1 At Parity (108 operators) 

All WOQL operators from the Python client are implemented in v0.3.2:

| Category | Count | Status |
|----------|-------|--------|
| Graph patterns (triple, quad, added/removed, add/delete/update) | 14 | Done |
| Logical combinators (and, or, not, opt, once, immediately, true) | 7 | Done |
| Query modifiers (select, distinct, limit, start, order_by, group_by, count, collect, star, all) | 10 | Done |
| Comparison (eq, less, greater, gte, lte, like) | 6 | Done |
| Schema ops (type_of, isa, sub, cast) | 4 | Done |
| Arithmetic (eval, plus, minus, times, divide, div, exp, floor, sum) | 9 | Done |
| String ops (concat, join, substr, trim, upper, lower, pad, split, length, regexp) | 10 | Done |
| List/Set/Dict (dot, member, slice, 5 set ops) | 8 | Done |
| Path (path/3, path/4 + 8 structured builders) | 10 | Done |
| ID generation (unique, idgen, idgen_random) | 3 | Done |
| Document mutations (read_document, insert_document, update_document, delete_document) | 4 | Done |
| Graph context (using, from, into, comment) | 4 | Done |
| Graph meta (size, triple_count) | 2 | Done |
| Range queries (triple_slice, quad_slice, rev, next, previous) | 8 | Done |
| Temporal/Allen (interval, Allen relations, date arithmetic, calendar, range) | 19 | Done |
| CSV/IO (get, put, woql_as, file, remote, post) | 6 | Done |
| Literal helpers (var, iri, string, boolean, datetime, date, literal, true_) | 8 | Done |
| RDF list library (17 functions via `WOQL.RDFList`) | 17 | Done |

### 2.2 Remaining Utility Gaps (3) ❌

| Python method | Description | Elixir plan |
|---|---|---|
| `graph/1` | Context setter for default graph | Deferred - `quad/4` explicit graph arg covers use cases |
| `load_vocabulary/1` | Query schema graph, populate short-name map | Not yet planned |
| `localize/1` (public) | Higher-order variable scope utility | Internal in `RDFList`; could expose if needed |

### 2.3 Elixir Advantage: Structured Path Builders 

Python's path DSL is string-only. Elixir provides both string parser and
structured builders (`path_star/1`, `path_plus/1`, `path_times/4`,
`path_seq/1`, `path_or/1`, `path_inverse/1`, `path_pred/1`, `path_any/0`).

---

## 3. Client API Coverage

### 3.1 At Parity 

| Category | Elixir modules | Methods | Status |
|----------|---------------|---------|--------|
| Connection & config | `Config` | 10 | Done |
| Database management | `Database` | 13 | Done |
| Document operations | `Document` | 11 | Done |
| Schema frames | `Schema` | 4 | Done |
| Branch management | `Branch` (incl. squash, reset) | 9 | Done |
| Commit history | `Commit` (incl. document_history) | 8 | Done |
| Diff & patch | `Diff` (incl. diff_object, patch, apply) + `Patch` | 18 | Done |
| Merge/rebase | `Merge` | 2 | Done |
| Prefix management | `Prefix` | 12 | Done |
| Triples (turtle) | `Triples` | 6 | Done |
| Remote collaboration | `Remote` (clone/fetch/push/pull) | 8 | Done |
| GraphQL | `GraphQL` | 3 | Done (net-new) |
| WOQL execution | `WOQL` (execute, execute!, execute_stream) | 3 | Done |
| Error handling | `Error` | 6 | Done |
| Telemetry | `Telemetry` | 3 | Done |
| Streaming | `Streaming` | 2 | Done |
| Client (wire) | `Client` | 4 | Done |

### 3.2 Remaining Gaps (3) ❌

| Feature | Description | Priority |
|---|---|---|
| Data version headers | `last_data_version` / `get_data_version` for optimistic concurrency | Low |
| Gzip compression | Compress large document inserts | Low |
| `load_vocabulary` | Query schema, populate prefix→suffix map for short names | Low |

### 3.3 Deferred: Access Control (16 methods) 

| Category | Methods | Count |
|----------|---------|-------|
| Organizations | `create_organization`, `get_organization`, `get_organizations`, `delete_organization` | 4 |
| Org users | `get_organization_users`, `get_organization_user`, `get_organization_user_databases` | 3 |
| Capabilities | `change_capabilities` | 1 |
| Roles | `add_role`, `change_role`, `get_available_roles` | 3 |
| Users | `add_user`, `get_user`, `get_users`, `delete_user`, `change_user_password` | 5 |

**Target:** v0.4+ - only needed for multi-tenant deployments.

---

## 4. Schema Definition System Gap

### Python: `WOQLSchema` / `DocumentTemplate` (64 classes/functions)

Python has a full schema definition system in `schema/schema.py`:

- `DocumentTemplate` - metaclass-based system for defining TerminusDB schemas
  as Python classes with typed properties
- `EnumTemplate` - enum definition for TerminusDB Enum types
- `TaggedUnion` - tagged union (sum type) definition
- `TerminusKey` / `HashKey` / `LexicalKey` / `ValueHashKey` / `RandomKey` -
  key generation strategies
- `Schema` - schema container that can serialize to/from JSON-LD, insert into
  database, and validate documents
- Type system: 30+ XSD types (`xsd:string`, `xsd:integer`, etc.)

Usage example (Python):
```python
class Person(DocumentTemplate):
    name: str
    age: int

class Animal(DocumentTemplate):
    _key = LexicalKey("name")
    name: str
    owner: Person
```

### Elixir: `Schema.frame/3` (read-only)

Elixir can read schema frames but has no schema definition macro. Schemas are
inserted as raw JSON-LD maps via `Document.insert/3` with `graph_type: :schema`.

### Plan: v0.4 (Ecto integration)

`use TerminusDB.Schema` macro - define TerminusDB schemas as Elixir structs
with typed fields, backed by Ecto types. ADR-0003 documents the strategy.

---

## 5. DataFrame Integration Gap

### Python: `WOQLDataFrame` (pandas)

Python has `woqldataframe/woqlDataframe.py` with `result_to_df()` - converts
WOQL query results to pandas DataFrames, with nested JSON expansion.

### Elixir: None

No equivalent. Explorer (Elixir's DataFrame library) integration is planned
for v0.4+ but not yet scoped in an ADR.

---

## 6. GraphQL Coverage

**Elixir has GraphQL support; Python does not.**

`TerminusDB.GraphQL` provides `query/3`, `mutate/3`, `introspect/2` - a thin
HTTP wrapper for TerminusDB's auto-generated GraphQL endpoint at
`/api/graphql/{org}/{db}`.

A programmatic GraphQL builder DSL is deferred to v0.3.3+.

---

## 7. Architectural Comparison

| Aspect | Elixir (`terminusdb_ex` v0.3.2) | Python (`terminusdb-client-python`) |
|--------|----------------------------------|--------------------------------------|
| **HTTP client** | `Req` (Elixir-native, Finch-backed) | `requests` |
| **Config model** | Immutable `Config` struct, `with_*` scoping | Mutable `Client` with setter properties |
| **WOQL DSL** | Functional builders returning `%WOQL.Query{}` structs | Fluent cursor mutating internal `_query` dict |
| **Results** | `{:ok, _} \| {:error, %Error{}}` tuples; `!/1` variants raise | Direct return or raises `DatabaseError` |
| **Telemetry** | `[:terminusdb, area, :start\|:stop]` on every op | None |
| **Streaming** | `Document.stream/2` (Req `into:`); `WOQL.execute_stream/3` | `_result2stream` iterator; `WoqlResult` |
| **Property tests** | StreamData round-trips + wrapper invariants | None |
| **ADRs** | 13 ADRs | 0 |
| **Coverage** | 92.8% (enforced ≥80%) | Not enforced |
| **Schema definition** | Read-only frames (v0.4: Ecto macro) | Full `DocumentTemplate` metaclass system |
| **DataFrame** | None (v0.4+: Explorer) | `WOQLDataFrame` (pandas) |
| **GraphQL** | `TerminusDB.GraphQL` (thin wrapper) | None |
| **Access control** | Not implemented (v0.4+) | 16 methods (orgs/users/roles/capabilities) |
| **Docs** | `ex_doc` + 9 guides + 13 ADRs + Livebook | Sphinx + tutorials |

---

## 8. Metrics Comparison

| Metric | Elixir v0.3.2 | Python (main) |
|--------|---------------|---------------|
| Public modules | 20 + 6 sub-modules | ~10 |
| WOQL operators | 133 defs (124 distinct + 8 aliases) | ~135 |
| RDF list functions | 17 | 17 |
| Client API methods | ~130 (incl. `!` variants) | ~72 |
| GraphQL methods | 3 | 0 |
| Schema definition | Read-only frames | Full metaclass system (64 classes) |
| DataFrame | None | pandas integration |
| Unit tests | 638 | ~500+ |
| Doctests | 155 | 0 |
| Property tests | 9 | 0 |
| Integration tests | 52 | ~50 |
| Coverage | 92.8% | Not enforced |
| ADRs | 13 | 0 |
| Guides | 9 (incl. Livebook) | Tutorials in `docs/` |
| Runtime deps | 4 | 2 (`requests`, `typeguard`) |
| Dev deps | 8 | ~5 |

---

## 9. Summary

After v0.3.2, the Elixir client has achieved **full WOQL operator parity** with
the Python client and **exceeds** it in several areas (GraphQL, telemetry,
property tests, ADRs, raising variants). The remaining gaps are:

1. **Schema definition system** - Python's `DocumentTemplate` metaclass vs
   Elixir's read-only `Schema.frame/3`. Planned for v0.4 via Ecto integration.
2. **DataFrame integration** - Python's pandas `WOQLDataFrame` vs none in
   Elixir. Explorer integration planned for v0.4+.
3. **Access control** - 16 methods for orgs/users/roles/capabilities. Deferred
   to v0.4+.
4. **Minor utility gaps** - `load_vocabulary`, data version headers, gzip
   compression. Low priority.

The Elixir client's architectural advantages (immutable config, tuple results,
telemetry, property-based testing, ADRs, 92.8% coverage) provide a strong
foundation for the v0.4 Ecto integration milestone.
