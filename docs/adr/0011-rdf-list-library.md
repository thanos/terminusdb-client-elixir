# ADR-0011: RDF list library composition

Date: 2026-06-25
Status: Accepted (implementation in v0.3.2)

## Context

The Python client provides 17 `rdflist_*` methods via a `WOQLLibrary` class,
accessed as `WOQLQuery().lib().rdflist_*(...)`. These methods compose WOQL
primitives (`triple`, `path`, `add_triple`, `delete_triple`, `idgen`, `eq`,
`length`, `group_by`) to manipulate RDF `rdf:List` structures.

Each method uses `localize()` — a higher-order utility that generates
collision-free variable names via a global counter (`VarsUnique`) — to prevent
variable name clashes with the caller's scope.

## Decision

Implement a new `TerminusDB.WOQL.RDFList` module with all 17 functions. Each
function composes `WOQL.Query` structs using existing `WOQL.*` builders.

### Variable collision avoidance

Implement an internal `localize/1` helper using `:erlang.unique_integer/1` to
generate process-unique variable names (e.g., `"v:RDFList_Head_12345"`). This
is simpler than Python's `VarsUnique` class and avoids global mutable state.

### Module placement

`lib/terminus_db/woql/rdf_list.ex` — follows the existing sub-module pattern
(`woql/encoder.ex`, `woql/decoder.ex`, `woql/path.ex`, `woql/literal.ex`).

### Functions

| Function | Arity | Description |
|----------|-------|-------------|
| `rdflist_list/2` | 2 | Collect all elements into array |
| `rdflist_peek/2` | 2 | Get first element |
| `rdflist_last/2` | 2 | Get last element |
| `rdflist_nth0/3` | 3 | 0-indexed element access |
| `rdflist_nth1/3` | 3 | 1-indexed element access |
| `rdflist_member/2` | 2 | Iterate elements as bindings |
| `rdflist_length/2` | 2 | List length |
| `rdflist_pop/2` | 2 | Pop first element in-place |
| `rdflist_push/2` | 2 | Push to front in-place |
| `rdflist_append/3` | 3 | Append to end |
| `rdflist_clear/2` | 2 | Delete all cons cells |
| `rdflist_empty/1` | 1 | Create empty list |
| `rdflist_is_empty/1` | 1 | Check if empty |
| `rdflist_slice/4` | 4 | Extract slice [start, end) |
| `rdflist_insert/4` | 4 | Insert at position |
| `rdflist_drop/2` | 2 | Drop element at position |
| `rdflist_swap/3` | 3 | Swap elements at two positions |

### Testing

Composition tests verify the composed query structure (not JSON-LD round-trip,
since RDF list ops produce composite `And` queries, not single `@type` ops).

## Consequences

- 1 new sub-module, 17 public functions, `localize/1` internal helper.
- ~34 new unit tests (structure + encoding per function).
- `localize/1` is internal; can be exposed publicly later if useful.

## Alternatives considered

1. **Port `WOQLLibrary` class pattern** — rejected (Elixir has no classes;
   module functions are more idiomatic).
2. **Generate via macros** — rejected (keep v0.3.2 purely functional per
   ADR-0008).
3. **Defer to v0.3.3** — rejected (high demand, core RDF functionality).
