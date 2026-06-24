# Introduction to TerminusDB

TerminusDB is an open-source **document graph database with built-in version
control**. It stores JSON documents in a schema-enforced graph, tracks every
change as an immutable commit, and supports branch, diff, merge, clone, and
time-travel operations, like Git but for structured data rather than files.

This guide explains the core concepts you need to use `terminusdb_ex` effectively.

---

## Documents

A **document** is a JSON object conforming to a schema class. Under the hood,
TerminusDB decomposes each document into RDF triples stored in a graph, but you
interact with it as plain JSON through the document API.

Every document has a `@type` (the class name) and an `@id` (a unique identifier
used for retrieval, updates, and cross-references):

```json
{
  "@type": "Person",
  "@id": "Person/Alice",
  "name": "Alice",
  "age": 30
}
```

### Document types

| Type | Description |
| --- | --- |
| **Document** | A top-level object with its own `@id`. Can be referenced by other documents. |
| **Subdocument** | Owned by its containing document. Cannot be referenced independently. Deleted when the parent is deleted. Use `@subdocument: []` in the class definition. |
| **Shared document** (`@shared`) | A regular document with its own IRI that can be referenced by any number of other documents. Automatically cascade-deleted when no document references it anymore. |

### Document keys (`@id` generation)

The `@key` field in a class definition controls how `@id` values are generated:

| Key type | Behaviour |
| --- | --- |
| `Random` | Auto-generates a random ID (default). |
| `Lexical` | Builds the ID from specified fields, sorted lexicographically. |
| `Hash` | Builds the ID from a hash of specified fields. |
| `ValueHash` | Hash of the entire document content. |

---

## Schema

A **schema** is a set of class definitions that describe the shape of documents.
Schemas are themselves documents (in the `schema` graph), written as JSON-LD.

A class definition specifies properties, their types, relationships, and
constraints:

```json
{
  "@type": "Class",
  "@id": "Person",
  "name": "xsd:string",
  "age": "xsd:integer",
  "email": "xsd:string",
  "address": "Address"
}
```

### Schema frames

A **frame** is the JSON-LD description of a class that TerminusDB returns from
the `/api/schema` endpoint. It includes the class's properties, their types,
key strategy, and documentation. Retrieve frames with `TerminusDB.Schema.frame/3`.

### Property types

| Type syntax | Meaning |
| --- | --- |
| `"xsd:string"` | String |
| `"xsd:integer"` | Integer |
| `"xsd:decimal"` | Decimal |
| `"xsd:dateTime"` | Timestamp |
| `"xsd:boolean"` | Boolean |
| `"ClassName"` | Reference to another document |
| `{"@type": "Set", "@class": "ClassName"}` | Unordered set of references |
| `{"@type": "List", "@class": "ClassName"}` | Ordered list of references |
| `{"@type": "Array", "@class": "ClassName"}` | Ordered, duplicates allowed |

### Two graphs

Each database has two named graphs:

| Graph | Contents |
| --- | --- |
| **instance** | Your data documents (the default for all document operations). |
| **schema** | Your class definitions. Pass `graph_type: :schema` to read or write schema documents. |

---

## Branches

TerminusDB provides **git-like version control for data**. Every commit is an
immutable delta layer (a record of what was added and removed). You can:

- **Branch** from an existing branch (default: `main`) to create an isolated
  copy of the data at that point in time.
- Make changes on the branch independently.
- **Merge** the branch back, or **diff** it against another branch to see
  exactly what changed.
- **Time-travel** by pinning a config to a specific commit ref.

### Resource addressing

Resources are addressed as `organization/database/repo/branch/ref`:

| Component | Default | Purpose |
| --- | --- | --- |
| `organization` | `admin` | The team that owns the database. |
| `database` | (none, must be scoped) | The database name. |
| `repo` | `local` | `local` or a remote name. |
| `branch` | `main` | The branch to read from / write to. |
| `ref` | (none) | A commit ref for time-travel queries. |

Use `TerminusDB.Config.with_database/2`, `with_branch/2`, `with_repo/2`, and
`with_ref/2` to scope an immutable config.

---

## Queries

TerminusDB offers three query mechanisms:

### 1. Document query (template matching)

The simplest approach: submit a JSON template and TerminusDB returns all
documents that match the shape. Use `TerminusDB.Document.query/3`:

```elixir
{:ok, matches} = TerminusDB.Document.query(config, %{"@type" => "Person", "age" => 30})
```

### 2. WOQL (Web Object Query Language)

A Datalog-based query language with unification. Variables use the `v:Name`
convention; shared variables create implicit joins (no JOIN syntax needed).
WOQL supports graph traversal, pattern matching, filtering, aggregation, and
recursion via path expressions.

WOQL queries are composed as an AST and serialized to JSON-LD. The WOQL DSL
for `terminusdb_ex` is planned for a later v0.2 release; until then, use
`TerminusDB.Client.request/4` to POST raw WOQL JSON to the `/api/woql` endpoint.

### 3. GraphQL

TerminusDB auto-generates a GraphQL schema from your class definitions. The
GraphQL endpoint is available at `/api/graphql/{org}/{db}`. GraphQL support in
`terminusdb_ex` is planned for a later v0.2 release.

---

## Indexes and storage

TerminusDB does not require you to create indexes manually. Under the hood:

- Data is stored as **RDF triples** in **succinct data structures** (compressed,
  content-addressed delta layers). All data is persisted on disk, but queries
  execute in-memory against the succinct representation, making reads fast.
- The succinct encoding is space-efficient: approximately **13 bytes per triple**
  on billion-triple datasets.
- Every commit appends a new immutable delta layer. Periodic **delta rollup**
  compresses accumulated layers to keep the in-memory footprint bounded.
- Because committed layers are immutable, **readers never block writers and
  writers never block readers** (lock-free concurrency).
- There are no separate indexes to tune. Graph traversal follows typed edges
  directly; the succinct layer stack is optimised for point lookups and
  pattern scans.

---

## Further reading

- [TerminusDB documentation](https://terminusdb.org/docs/)
- [Document model](https://terminusdb.org/docs/documents-explanation/)
- [Schema reference](https://terminusdb.org/docs/schema-reference-guide/)
- [WOQL explanation](https://terminusdb.org/docs/woql-explanation/)
- [Version control](https://terminusdb.org/docs/use-the-collaboration-features/)
