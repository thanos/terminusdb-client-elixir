# ADR-0012: CSV / IO and QueryResource encoding

Date: 2026-06-25
Status: Accepted (implementation in v0.3.2)

## Context

The Python client provides 6 CSV/IO operators: `get`, `put`, `woql_as`,
`file`, `remote`, `post`. These enable reading/writing CSV data from files,
remote URLs, or posted content as part of WOQL queries.

## Decision

Implement all 6 operators in the `WOQL` module with encoder/decoder clauses.

### Operators

| Function | Arity | JSON-LD `@type` | Description |
|----------|-------|-----------------|-------------|
| `get/2` | 2 | `Get` | Read CSV/columns resource |
| `put/3` | 3 | `Put` | Write array of variables + optional columns |
| `woql_as/1` | 1 | (list of `Column`) | Map column names/indices to variables |
| `file/2` | 2 | `QueryResource` | File source (CSV format) |
| `remote/2` | 2 | `QueryResource` | Remote URL data source |
| `post/2` | 2 | `QueryResource` | File posted as part of request |

### `woql_as/1` column mapping

`woql_as/1` accepts a list of `{name_or_index, variable}` tuples and builds
`Column`/`Indicator` JSON-LD objects:

```json
{
  "@type": "Column",
  "indicator": {"@type": "Indicator", "name": "column_name"},
  "variable": "var_name"
}
```

For integer indices: `"indicator": {"@type": "Indicator", "index": 0}`.

### QueryResource encoding

`file/2`, `remote/2`, `post/2` build `QueryResource` objects with a `source`
field and optional `format` field:

```json
{
  "@type": "QueryResource",
  "source": {"@type": "FileResource", "file_name": "path"},
  "format": {"@type": "Format", "format_type": {"@type": "xsd:string", "@value": "csv"}}
}
```

### Options

- `file/2` opts: `:format` (default `"csv"`)
- `remote/2` opts: `:format` (default `"csv"`)
- `post/2` opts: `:format` (default `"csv"`)

## Consequences

- 6 new operators, 6 encoder clauses, 6 decoder clauses.
- ~25 new unit tests.
- `woql_as/1` is a helper, not a standalone WOQL operator — it builds a list
  of `Column` objects used by `get/2` and `put/3`.

## Alternatives considered

1. **Defer CSV/IO** — rejected (identified as high-priority gap).
2. **Separate `WOQL.CSV` module** — rejected (ops are WOQL operators; keeping
   them in `WOQL` matches Python).
