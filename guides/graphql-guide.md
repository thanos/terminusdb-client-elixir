# GraphQL Guide

TerminusDB auto-generates a GraphQL endpoint from your database's document schema. The `terminusdb_ex` client provides a thin HTTP wrapper for sending GraphQL queries and mutations.

## Connecting

```elixir
config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
  |> TerminusDB.Config.with_database("mydb")
```

## Queries

```elixir
{:ok, result} = TerminusDB.GraphQL.query(config, "{ Person { name age } }")
# => {:ok, %{data: %{"Person" => [%{"name" => "Alice", "age" => 30}]}, errors: nil}}
```

### Filtering

```elixir
{:ok, result} = TerminusDB.GraphQL.query(config, """
  {
    Person(filter: {name: {eq: "Alice"}}) {
      name
      age
    }
  }
""")
```

### Pagination

```elixir
{:ok, result} = TerminusDB.GraphQL.query(config, """
  {
    Person(limit: 10, offset: 20) { name }
  }
""")
```

### Ordering

```elixir
{:ok, result} = TerminusDB.GraphQL.query(config, """
  {
    Person(orderBy: {name: ASC}) { name }
  }
""")
```

### Path queries

```elixir
{:ok, result} = TerminusDB.GraphQL.query(config, """
  {
    Person {
      name
      _path(friend+: { name: "Bob" }) { name }
    }
  }
""")
```

### Backlinks

```elixir
{:ok, result} = TerminusDB.GraphQL.query(config, """
  {
    Person {
      name
      _backlink(friend: {}) { name }
    }
  }
""")
```

### Count

```elixir
{:ok, result} = TerminusDB.GraphQL.query(config, """
  {
    Person { _count }
  }
""")
```

## Mutations

### Insert documents

```elixir
{:ok, result} = TerminusDB.GraphQL.mutate(config, """
  mutation {
    _insertDocuments(json: "{\\"@type\\":\\"Person\\",\\"name\\":\\"Alice\\"}")
  }
""")
```

### Replace documents

```elixir
{:ok, result} = TerminusDB.GraphQL.mutate(config, """
  mutation {
    _replaceDocuments(json: "{\\"@id\\":\\"Person/Alice\\",\\"name\\":\\"Alicia\\"}", create: true)
  }
""")
```

### Delete documents

```elixir
{:ok, result} = TerminusDB.GraphQL.mutate(config, """
  mutation {
    _deleteDocuments(ids: ["Person/Alice"])
  }
""")
```

### With commit info

```elixir
{:ok, result} = TerminusDB.GraphQL.mutate(config, """
  mutation {
    _insertDocuments(json: "{\\"@type\\":\\"Person\\",\\"name\\":\\"Bob\\"}") {
      _commitInfo { author message }
    }
  }
""")
```

## Introspection

```elixir
{:ok, schema} = TerminusDB.GraphQL.introspect(config)
# => {:ok, %{"__schema" => %{"types" => [...]}}}
```

## Variables

```elixir
{:ok, result} = TerminusDB.GraphQL.query(config, """
  query($name: String) {
    Person(filter: {name: {eq: $name}}) { name }
  }
""", %{"name" => "Alice"})
```

## Error handling

```elixir
case TerminusDB.GraphQL.query(config, "{ Person { name } }") do
  {:ok, %{data: data, errors: nil}} ->
    # Success
    IO.inspect(data)

  {:ok, %{data: nil, errors: errors}} ->
    # GraphQL errors
    IO.inspect(errors)

  {:error, error} ->
    # HTTP/transport error
    IO.inspect(error)
end
```
