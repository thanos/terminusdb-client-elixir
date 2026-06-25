# Architecture - terminusdb_ex

This document records the review of TerminusDB, the existing client ecosystem, and the
architecture decisions for `terminusdb_ex`, the Elixir client. It is the canonical
reference for contributors. Detailed, single-concern records live in `docs/adr/`.

---

## 1. Review summary

### 1.1 TerminusDB

TerminusDB is an open-source **document graph database with built-in version control**.
It stores JSON documents as a graph of RDF triples, tracks every change as an immutable
commit, and supports git-for-data workflows: branches, commits, diffs, merges, push,
pull, clone, fetch, squash, and reset (time-travel).

Key concepts:

| Concept | Description |
| --- | --- |
| **Document** | A JSON object conforming to a schema class, stored as linked triples. |
| **Schema** | A graph of `Class` documents with typed properties; optional per database. |
| **Graph** | Two named graphs per branch: `instance` (data) and `schema` (types). |
| **Branch / Repo / Ref** | `organization/database/repo/branch/commit_ref` resource addressing. |
| **Commit** | Immutable snapshot; chain of commits gives full history. |
| **WOQL** | Web Object Query Language - a datalog query language serialized as JSON-LD. |
| **GraphQL** | Auto-generated GraphQL endpoint over the schema. |
| **JSON-LD** | The wire format for documents and WOQL queries. |

#### REST API surface (OpenAPI v10.0.x)

Base URL: `http://<host>:6363/api/`. Auth: HTTP Basic (`admin:root` by default).

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/` | GET | List databases for the authenticated user |
| `/info` | GET | Server version / capabilities |
| `/ok` | GET | Liveness check |
| `/db/` | GET | List all databases (`branches`, `verbose`) |
| `/db/{org}/{db}` | GET | Database details |
| `/db/{org}/{db}` | HEAD | Check a database exists |
| `/db/{org}/{db}` | POST | Create a database (body: `label`, `comment`, `public`, `schema`) |
| `/db/{org}/{db}` | PUT | Update database metadata |
| `/db/{org}/{db}` | DELETE | Delete a database (`force`) |
| `/document/{path}` | GET | Get documents (`graph_type`, `id`, `type`, `skip`, `count`, `as_list`, `unfold`, `minimized`, `compress_ids`) |
| `/document/{path}` | POST | Insert documents (`author`, `message`, `graph_type`, `full_replace`, `raw_json`) |
| `/document/{path}` | PUT | Replace documents (`create`, `raw_json`) |
| `/document/{path}` | DELETE | Delete documents (`id`, `nuke`) |
| `/schema` | GET | Class frame (`compress_ids`, `expand_abstract`) |
| `/woql`, `/woql/{path}` | POST | Execute a WOQL query (body: `query`, `commit_info`, `all_witnesses`) |
| `/branch/{path}` | POST/DELETE | Create / delete a branch |
| `/squash/{path}` | GET | Squash commits |
| `/reset/{path}` | POST | Reset branch HEAD to a commit |
| `/optimize/{path}` | POST | Optimize a resource |
| `/prefixes/{path}` | GET | Fetch graph prefixes |
| `/clone/{org}/{db}` | POST | Clone a remote database |
| `/fetch/{path}` | POST | Fetch from a remote |
| `/push/{path}` | POST | Push to a remote |
| `/pull/{path}` | POST | Pull from a remote |
| `/diff` | POST | Diff two documents (`before`, `after`, `keep`) |
| `/patch` | POST | Apply a patch (`before`, `patch`) |

**Error model:** failures return HTTP 4xx/5xx with a JSON body of the shape
`{"@type": "api:*ErrorResponse", "api:error": {...}, "api:message": "...", "api:status": "api:failure"}`.

#### WOQL

WOQL is a composable, declarative query language backed by a datalog engine. Queries are
built as an AST and serialized to JSON-LD. Variables use the `v:Name` convention and unify
across the query (shared variables create implicit joins). The language supports functional
style (`and(triple(a,b,c), triple(d,e,f))`) and fluent style; functional is recommended.
Because WOQL is itself datalog, it is the natural compilation target for an ExDatalog
integration (see ADR-0004).

### 1.2 Python client (`terminusdb`)

The official Python client is the reference for API ergonomics.

**Strengths:**
- Single `Client(server_url)` entry point with `connect(...)` that establishes credentials
  and the current `team`/`db`/`branch`/`repo`/`ref` context.
- Document API is high-level and Pythonic: `insert_document`, `get_document`,
  `query_document`, `replace_document`, `update_document`, `delete_document`.
- `WOQLQuery` builder object compiles to JSON-LD.
- Token + JWT + basic-auth support.

**Weaknesses / opportunities for Elixir:**
- The client is **mutable and stateful**: connection context is held on the instance and
  mutated by setters. This maps poorly to Elixir and to concurrency. An Elixir client
  should treat context as **immutable data** carried in a struct, with explicit scope
  overrides per call.
- Error handling is exception-based with a large `APIError` hierarchy; Elixir can do
  better with a single typed `TerminusDB.Error` struct and `{:ok, _} | {:error, _}` tuples.
- No streaming of large result sets; the document GET returns concatenated JSON. Elixir
  can stream via `Req`'s `into:` option and `Stream`/`Enumerable`.
- No telemetry. Elixir can emit `:telemetry` events uniformly.
- No schema-to-struct mapping. Elixir can leverage `Ecto.Schema` for this (ADR-0003).

### 1.3 Elixir ecosystem review

| Library | Role | Decision |
| --- | --- | --- |
| **Req** | High-level HTTP client on Finch; built-in JSON, params, auth, retry, streaming, fake adapter for tests | **Selected** HTTP client (ADR-0001) |
| **Jason** | JSON codec (Req default decoder) | **Selected** |
| **NimbleOptions** | Lightweight schema validation for config/options | **Selected** for `Config` + API options |
| **Telemetry** | Standard instrumentation | **Selected** (ADR-0005) |
| Tesla / Finch | Alternatives to Req | Req preferred: batteries-included, testable, streaming |
| Ecto | Schema/changeset for the `TerminusDB.Schema` macro (ADR-0003) | Optional dep, not a full adapter in v0.1 |
| Explorer | DataFrame interop | Future work, not in v0.1 |
| StreamData | Property-based testing | **Selected** dev dep (ADR-0006) |

---

## 2. Architecture options

### Option A - Pure HTTP client
A thin, faithful wrapper over the REST API. Lowest complexity, fastest to ship, but
leaves all schema/struct ergonomics to the user.

### Option B - Client + Ecto integration
A adds `use TerminusDB.Schema` (built on `Ecto.Schema` + `Ecto.Changeset`) so users model
documents as Elixir structs and generate TerminusDB schema definitions. Major ergonomics
win; Ecto is an optional dependency.

### Option C - Client + Ecto + ExDatalog
B adds a Datalog DSL that compiles rules to WOQL JSON-LD and can load query results back
into an in-process Datalog engine. Highest value for knowledge-graph and reasoning workloads.

### Option D - Client + local graph engine
C adds a local in-process graph store for offline/cached querying. Largest scope; risks
reimplementing the database. **Not justified** for a client library - TerminusDB itself is
the graph engine.

### Decision

**Adopt Option C as the target architecture, delivered incrementally.**

- **v0.1 (done):** Option A core - `Client`, `Config`, `Error`, `Database`,
  telemetry, and the HTTP/wire primitives.
- **v0.2 (done):** Document CRUD + query + streaming, Schema frame retrieval,
  Branch management, and the concatenated-JSON streaming decoder.
- **v0.3 (done):** Commit history, Diff, Merge (rebase), WOQL functional DSL
  v0.1, TerminusDB 12 compatibility, and integration tests.
- **v0.3.1+:** GraphQL, expanded WOQL vocabulary, benchmarks, tutorials.
- **v0.4:** Ecto integration (`TerminusDB.Schema`) - Option B.
- **v0.5:** ExDatalog integration - Option C.
- **Option D is rejected** for v0.x; a local engine is out of scope for a client.

This sequencing gives a usable, tested client immediately and de-risks the harder
integrations by building them on a solid HTTP core.

---

## 3. High-level design

```
TerminusDB
├── Application           OTP supervision tree
├── Config                immutable connection/context (NimbleOptions-validated)
├── Client                Req-based HTTP wrapper; the only module that touches the wire
│   └── Params            internal query-param helpers (flag/bool)
├── Error                 typed error struct + exception
├── Database              database management API
├── Document              document CRUD + query + streaming   ✓ v0.2
├── Schema                schema frame API                    ✓ v0.2
├── Branch                branch API                          ✓ v0.2
├── Streaming             concatenated-JSON stream decoder    ✓ v0.2
├── Commit                history / log                       ✓ v0.3
├── Diff                  diff / compare                      ✓ v0.3
├── Merge                 rebase / merge                       ✓ v0.3
├── WOQL                  functional DSL → JSON-LD            ✓ v0.3
├── GraphQL               GraphQL execution                   (v0.3.1+)
├── Datalog               ExDatalog integration               (v0.5)
└── Telemetry             event definitions + helpers
```

### 3.1 Principles

1. **Immutable context.** A `TerminusDB.Config` struct holds `endpoint`, `auth`,
   `organization`, `database`, `branch`, `repo`, `ref`. Every API call takes a config and
   returns derived configs (`TerminusDB.Config.with_database/2`, `TerminusDB.Config.with_branch/2`) rather than
   mutating. This is concurrent-safe and matches Elixir idioms - and corrects the Python
   client's mutable-state design.
2. **One wire module.** `TerminusDB.Client` is the *only* module that issues HTTP requests.
   All API modules (`Database`, `Document`, …) compose a request and hand it to
   `Client.request/2`. This centralizes auth, headers, JSON, telemetry, retry, and errors.
3. **Typed errors, tuple results.** Public functions return `{:ok, result}` or
   `{:error, %TerminusDB.Error{}}`. A companion `!/1` variant raises `TerminusDB.Error`.
4. **Telemetry everywhere.** Every public operation emits `[:terminusdb, <area>, :start]`
   and `[:stop]` events with measurements and metadata (ADR-0005).
5. **Streaming first where it matters.** Document listing and query results offer
   `Stream`/`Enumerable` variants backed by Req's `into:` option (ADR-0007).
6. **Minimal dependencies.** Only `req`, `jason`, `nimble_options`, `telemetry` for v0.1.
   Ecto becomes an optional dependency only when `TerminusDB.Schema` lands.

### 3.2 Request flow

```
API module (e.g. Database.create/3)
  └─ builds path + body + query params
  └─ calls Client.request(config, method, path, opts)
       ├─ Telemetry.start
       ├─ Req.request!(base_url, auth, json, params, ...)
       ├─ on 2xx → decode body → Telemetry.stop → {:ok, body}
       └─ on 4xx/5xx → build TerminusDB.Error → Telemetry.stop(exception:) → {:error, error}
```

### 3.3 Resource addressing

TerminusDB addresses resources as `organization/database/repo/branch/ref`. The config
struct carries these; path builders in `TerminusDB.Client.Path` assemble the correct
URL segment for each endpoint (e.g. `/db/:org/:db`, `/document/:org/:db`).
