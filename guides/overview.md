# Overview Guide

A walkthrough of every feature in `terminusdb_ex` v0.3. Each section demonstrates
a module with runnable examples (against a live TerminusDB at
`http://localhost:6363`).

## Setup

Start a TerminusDB server:

```bash
docker compose up -d
until curl -sf http://localhost:6363/api/ok >/dev/null 2>&1; do sleep 1; done
```

Then in an Elixir shell (`iex -S mix`):

```elixir
alias TerminusDB.{Config, Database, Document, Schema, Branch, Commit, Diff, Merge, WOQL, Client, Error}
```

## 1. Configuration (immutable context)

`TerminusDB.Config` is an immutable struct carrying the server endpoint,
credentials, and resource scope. All API functions take a config and return
derived configs via `with_*` helpers, never mutating.

```elixir
# Basic config with default admin:root auth
config = Config.new(endpoint: "http://localhost:6363")

# With a bearer token
config = Config.new(endpoint: "http://localhost:6363", token: "tok_abc")

# Inspect the auth tuple
Config.auth(config)
# => {:bearer, "tok_abc"}

# Redact secrets for logging / telemetry
Config.redact(config).token
# => "[redacted]"
```

## 2. Database management

Create, inspect, update, and delete databases.

```elixir
# Create
{:ok, _} = Database.create(config, "demo", label: "Demo DB", schema: true)

# Check existence
Database.exists?(config, "demo")  # => true
Database.exists?(config, "nope")  # => false

# Get info
{:ok, details} = Database.info(config, "demo")

# List all databases
{:ok, all} = Database.list(config)

# Update metadata
{:ok, _} = Database.update(config, "demo", label: "Renamed DB")

# Delete
{:ok, _} = Database.delete(config, "demo")
```

## 3. Document CRUD

Insert, retrieve, query, replace, and delete documents. Requires a config scoped
to a database.

```elixir
config = Config.with_database(config, "demo")

# Insert a schema (Class document in the schema graph)
{:ok, _} =
  Document.insert(config,
    %{"@type" => "Class", "@id" => "Person", "name" => "xsd:string", "age" => "xsd:integer"},
    author: "admin", message: "add schema",
    graph_type: :schema
  )

# Insert a document
{:ok, _} =
  Document.insert(config,
    %{"@type" => "Person", "name" => "Alice", "age" => 30},
    author: "admin", message: "add Alice"
  )

# Insert multiple documents at once
{:ok, _} =
  Document.insert(config, [
    %{"@type" => "Person", "name" => "Bob", "age" => 25},
    %{"@type" => "Person", "name" => "Carol", "age" => 28}
  ], author: "admin", message: "add more people")

# Get all documents of a type
{:ok, docs} = Document.get(config, type: "Person", as_list: true)

# Get a specific document by ID
{:ok, person} = Document.get(config, id: "Person/Alice")

# Query by template
{:ok, matches} = Document.query(config, %{"@type" => "Person", "age" => 30})

# Replace (update) a document
{:ok, _} =
  Document.replace(config,
    %{"@id" => "Person/Alice", "name" => "Alicia", "age" => 31},
    author: "admin", message: "rename Alice"
  )

# Delete a document
{:ok, _} = Document.delete(config, id: "Person/Alice", author: "admin", message: "remove")
```

## 4. Schema frames

Retrieve the schema frame (JSON-LD class description) for a class or all classes.

```elixir
# Frame for a specific class
{:ok, frame} = Schema.frame(config, "Person")
# => %{"@type" => "Class", "name" => "xsd:string", "age" => "xsd:integer"}

# All class frames
{:ok, all} = Schema.all(config)
# => %{"Person" => %{"@type" => "Class", ...}}

# With options
{:ok, frame} = Schema.frame(config, "Person", compress_ids: false, expand_abstract: false)
```

## 5. Branches

Create, check, and delete branches (git-like version control for data).

```elixir
# Create a branch (forks from main by default)
{:ok, _} = Branch.create(config, "feature")

# Fork from a specific branch
{:ok, _} = Branch.create(config, "dev", from: "main")

# Check existence
Branch.exists?(config, "feature")  # => true

# Work on the branch
feature_config = Config.with_branch(config, "feature")
{:ok, _} = Document.insert(feature_config,
  %{"@type" => "Person", "name" => "Dave"},
  author: "admin", message: "add Dave on feature branch"
)

# Delete the branch
{:ok, _} = Branch.delete(config, "feature")
```

## 6. Streaming

Stream large document result sets with constant memory using Req's async response
and the concatenated-JSON decoder.

```elixir
# Stream all Person documents
Document.stream(config, type: "Person")
|> Stream.each(&IO.inspect/1)
|> Stream.run()

# Count without loading all into memory
count = Document.stream(config, type: "Person") |> Enum.count()
```

## 7. Telemetry

Every operation emits `[:terminusdb, <area>, :start]` and `[:stop]` events.

```elixir
# Attach a handler
:telemetry.attach_many(
  "my-handler",
  [[:terminusdb, :document, :stop], [:terminusdb, :database, :stop]],
  fn _event, measurements, meta, _ctx ->
    IO.puts("[#{meta.area}] #{meta.method} #{meta.path} -> #{meta.status} (#{measurements[:duration]} ns)")
  end,
  nil
)

# Now operations emit events:
{:ok, _} = Database.create(config, "telemetry_test", label: "Test")
# [database] :post db/admin/telemetry_test -> 200 (1234567 ns)

:telemetry.detach("my-handler")
```

## 8. Error handling

All public functions return `{:ok, result}` or `{:error, %TerminusDB.Error{}}`.
The `!/` variants raise instead.

```elixir
# Tuple-returning (non-raising)
case Database.create(config, "demo", label: "Demo") do
  {:ok, _} -> :ok
  {:error, %Error{reason: :api, api_type: "api:DatabaseAlreadyExists"} = e} ->
    IO.puts("Database already exists: #{Exception.message(e)}")
  {:error, %Error{reason: :transport} = e} ->
    IO.puts("Network error: #{Exception.message(e)}")
end

# Raising variant
Database.create!(config, "demo", label: "Demo")
# raises TerminusDB.Error if it fails
```

## 9. Raw client access

For endpoints not yet wrapped by a higher-level module, use `Client.request/4`
directly.

```elixir
# Raw GET
{:ok, body} = Client.request(config, :get, "ok")

# Raw POST with JSON body
{:ok, resp} = Client.request(config, :post, "db/admin/mydb",
  json: %{label: "My DB", schema: true},
  area: :database
)

# Get the full Req.Response (headers, status, body)
{:ok, resp} = Client.request_response(config, :get, "info")
resp.status  # => 200
resp.headers["content-type"]  # => ["application/json"]
```

## 10. Commit history

Every write to TerminusDB creates an immutable commit. Use `TerminusDB.Commit`
to traverse the commit chain on a branch.

```elixir
# List recent commits on the current branch
{:ok, log} = Commit.log(config)
# => [
#   %{"@id" => "commit/abc...", "author" => "admin", "message" => "add Alice", ...},
#   %{"@id" => "commit/def...", "author" => "admin", "message" => "add schema", ...}
# ]

# Full history (same endpoint, all commits)
{:ok, history} = Commit.history(config)

# Paginate: start from a specific commit, limit results
{:ok, page} = Commit.log(config, start: "commit/abc...", limit: 5)

# Inspect a single commit by descriptor ID
{:ok, commit} = Commit.get(config, "commit/abc...")
# => %{"@id" => "commit/abc...", "author" => "admin", "message" => "add Alice", ...}

# History on a different branch
feature_config = Config.with_branch(config, "feature")
{:ok, feature_log} = Commit.log(feature_config)
```

## 11. Diff

Compare two document states or branch/commit refs with `TerminusDB.Diff`.

```elixir
# Diff two document values
{:ok, patch} = Diff.compare(config,
  before: %{"@id" => "Person/Alice", "name" => "Alice", "age" => 30},
  after: %{"@id" => "Person/Alice", "name" => "Alicia", "age" => 31}
)
# => %{"name" => %{"@op" => "ValueSwap", "@before" => "Alice", "@after" => "Alicia"}, ...}

# Diff two branches
{:ok, branch_diff} = Diff.compare(config,
  before: "admin/mydb/local/branch/main",
  after: "admin/mydb/local/branch/feature"
)

# Preserve certain fields in the diff output
{:ok, patch} = Diff.compare(config,
  before: %{"@id" => "Person/Alice", "name" => "Alice"},
  after: %{"@id" => "Person/Alice", "name" => "Alicia"},
  keep: %{"@id" => true}
)
```

## 12. Merge

TerminusDB uses a rebase model for merging: the source branch's commits are
replayed on top of the target branch. Use `TerminusDB.Merge` to merge branches.

```elixir
# Create a feature branch and diverge
{:ok, _} = Branch.create(config, "feature")
feature_config = Config.with_branch(config, "feature")

Document.insert!(feature_config,
  %{"@type" => "Person", "name" => "Dave"},
  author: "admin", message: "add Dave on feature"
)

# Merge feature into main
{:ok, result} = Merge.merge(config,
  source_branch: "feature",
  target_branch: "main",
  author: "admin",
  message: "merge feature into main"
)
# => %{"api:status" => "api:success", "api:forwarded_commits" => [...]}

# Dave is now on main
{:ok, docs} = Document.get(config, type: "Person", as_list: true)
"Dave" in Enum.map(docs, & &1["name"])  # => true

# Clean up the branch
{:ok, _} = Branch.delete(config, "feature")
```

## 13. WOQL DSL

WOQL (Web Object Query Language) is TerminusDB's Datalog-based query language.
Use `TerminusDB.WOQL` to build composable queries functionally, serialize to
JSON-LD, and execute.

```elixir
import TerminusDB.WOQL

# Build a query: find all Persons and their names
query =
  select(["v:Name"],
    and_([
      triple("v:Person", "rdf:type", "@schema:Person"),
      triple("v:Person", "name", "v:Name")
    ])
  )

# Execute against the database
{:ok, result} = WOQL.execute(config, query)
# => %{"bindings" => [%{"Name" => "Alice"}, %{"Name" => "Bob"}, ...]}

# Query with an equality filter
query =
  select(["v:Name"],
    and_([
      triple("v:Person", "name", "v:Name"),
      eq("v:Name", "Alice")
    ])
  )

{:ok, result} = WOQL.execute(config, query)
# => %{"bindings" => [%{"Name" => "Alice"}]}

# Read a single document by ID
query = read_document("Person/Alice", "v:Doc")
{:ok, result} = WOQL.execute(config, query)

# Check the type of a node
query = type_of("v:Person", "v:Type")
{:ok, result} = WOQL.execute(config, query)

# Serialize to JSON-LD (inspect the wire format)
jsonld = WOQL.to_jsonld(query)
# => %{"@type" => "TypeOf", "value" => %{"@type" => "DataValue", ...}, ...}

# Deserialize back
WOQL.from_jsonld(jsonld)  # => %WOQL.Query{op: :type_of, args: [...]}

# Write query with commit metadata
query =
  and_([
    triple("v:New", "rdf:type", "@schema:Person"),
    triple("v:New", "name", "v:Name"),
    eq("v:Name", "Eve")
  ])

{:ok, _} = WOQL.execute(config, query, author: "admin", message: "add Eve via WOQL")
```

### Supported WOQL vocabulary (v0.1)

| Function | WOQL type | Description |
| --- | --- | --- |
| `triple/3` | `Triple` | Match or create a triple (subject, predicate, object) |
| `and_/1` | `And` | Conjunction of sub-queries |
| `or_/1` | `Or` | Disjunction of sub-queries |
| `eq/2` | `Equals` | Unify left and right |
| `select/2` | `Select` | Project variables from a sub-query |
| `read_document/2` | `ReadDocument` | Read a document by ID into a variable |
| `type_of/2` | `TypeOf` | Unify the type of a node with a variable |

Variables use the `v:Name` convention. The DSL is purely functional (no macros)
and composes by nesting. Future releases will add more vocabulary.

## Cleanup

```elixir
{:ok, _} = Database.delete(config, "demo", force: true)
```
