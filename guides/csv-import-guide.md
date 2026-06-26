# CSV Import / Export Guide

TerminusDB provides WOQL CSV/IO operators for reading and writing CSV data from files, remote URLs, or posted content.

## Reading CSV

```elixir
import TerminusDB.WOQL

# Read a CSV file with column mapping
query =
  get(
    woql_as([{"name", "v:Name"}, {"age", "v:Age"}]),
    file("data.csv")
  )

# Execute to load the data
{:ok, result} = TerminusDB.WOQL.execute(config, query, author: "admin", message: "import CSV")
```

### Column mapping with `woql_as`

```elixir
import TerminusDB.WOQL

# By column name
cols = woql_as([{"name", "v:Name"}, {"email", "v:Email"}])

# By column index (0-based)
cols = woql_as([{0, "v:First"}, {1, "v:Second"}])

# Mixed
cols = woql_as([{"name", "v:Name"}, {1, "v:Email"}])
```

### Reading from a remote URL

```elixir
import TerminusDB.WOQL

query =
  get(
    woql_as([{"name", "v:Name"}, {"age", "v:Age"}]),
    remote("https://example.com/data.csv")
  )
```

### Reading a posted file

```elixir
import TerminusDB.WOQL

query =
  get(
    woql_as([{"name", "v:Name"}]),
    post("upload.csv")
  )
```

## Writing CSV

```elixir
import TerminusDB.WOQL

# Write query results to a CSV file
query =
  put(
    woql_as([{"name", "v:Name"}, {"age", "v:Age"}]),
    and_([
      triple("v:Person", "name", "v:Name"),
      triple("v:Person", "age", "v:Age")
    ]),
    file("output.csv")
  )

{:ok, result} = TerminusDB.WOQL.execute(config, query, author: "admin", message: "export CSV")
```

## Custom formats

```elixir
import TerminusDB.WOQL

# JSON format instead of CSV
query = get(woql_as([{"name", "v:Name"}]), file("data.json", format: "json"))
```

## Combining CSV import with schema insertion

```elixir
import TerminusDB.WOQL

# Read CSV and insert as documents
query =
  and_([
    get(
      woql_as([{"name", "v:Name"}, {"age", "v:Age"}]),
      file("people.csv")
    ),
    unique("Person", ["v:Name"], "v:Id"),
    add_triple("v:Id", "rdf:type", iri("@schema:Person")),
    add_triple("v:Id", "name", "v:Name"),
    add_triple("v:Id", "age", "v:Age")
  ])

{:ok, result} = TerminusDB.WOQL.execute(config, query, author: "admin", message: "import people")
```
