# RDF List Library Guide

TerminusDB provides 17 functions for manipulating RDF `rdf:List` structures via `TerminusDB.WOQL.RDFList`.

## Overview

RDF lists are linked lists built from `rdf:List` cons cells. Each cell has:
- `rdf:first` — the element value
- `rdf:rest` — a pointer to the next cell (or `rdf:nil` for the empty list)

## Reading

### Get the first element

```elixir
import TerminusDB.WOQL

query = and_([
  triple("v:List", "rdf:type", iri("rdf:List")),
  TerminusDB.WOQL.RDFList.rdflist_peek("v:List", "v:First")
])
```

### Get the last element

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_last("v:List", "v:Last")
```

### Get element at position

```elixir
# 0-indexed
query = TerminusDB.WOQL.RDFList.rdflist_nth0("v:List", 2, "v:Elem")

# 1-indexed
query = TerminusDB.WOQL.RDFList.rdflist_nth1("v:List", 3, "v:Elem")
```

### Iterate all elements

```elixir
# Each element as a separate binding
query = TerminusDB.WOQL.RDFList.rdflist_member("v:List", "v:Elem")

# All elements as an array
query = TerminusDB.WOQL.RDFList.rdflist_list("v:List", "v:Array")
```

### Get length

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_length("v:List", "v:Len")
```

### Check if empty

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_is_empty("v:List")
```

### Create an empty list

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_empty("v:List")
```

## Mutation

### Push (prepend)

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_push("v:List", "v:Value")
```

### Pop (remove first)

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_pop("v:List", "v:Value")
```

### Append

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_append("v:List", "v:Value")
```

### Clear

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_clear("v:List", "v:NewList")
```

### Insert at position

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_insert("v:List", 1, "v:Value")
```

### Drop at position

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_drop("v:List", 1)
```

### Swap elements

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_swap("v:List", 0, 2)
```

### Slice

```elixir
query = TerminusDB.WOQL.RDFList.rdflist_slice("v:List", 0, 3, "v:Result")
```

## Variable safety

All `RDFList` functions use an internal `localize` helper that generates
process-unique variable names (e.g., `v:RDFList_head_12345`) to avoid
collisions with your query's variables.
