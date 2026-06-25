# ADR-0008: WOQL DSL v0.2 — vocabulary expansion, 4-wrapper value model, dual path DSL

Date: 2026-06-25
Status: Accepted (implementation in v0.3.1)
Supersedes/extends: ADR-0002

## Context

ADR-0002 introduced a plain functional builder DSL for WOQL and shipped in v0.2/v0.3
with a 7-operator subset (`triple`, `and_`, `or_`, `eq`, `select`, `read_document`,
`type_of`). A gap analysis against the Python client (`terminusdb-client-python`)
revealed ~120 operators across logical, modifier, graph-pattern, comparison, schema,
arithmetic, string, list/set, path, document, ID-generation, graph-context, graph-meta,
temporal/Allen, CSV/IO, and RDF-list-library families.

The v0.1 encoder also diverged from the Python/JS wire-format model in three ways that
block correct encoding of arithmetic, string, and several other operator families:

1. It used only two value wrappers (`NodeValue`, `DataValue`) where the canonical model
   uses four (`NodeValue`, `Value`, `DataValue`, `ArithmeticValue`), each with distinct
   valid fields (`node` vs `data` vs `variable`).
2. `read_document/2` placed the document id under `"document"` and the output variable
   under `"identifier"`; the canonical model is the reverse.
3. `triple` constant string objects were encoded as IRIs (`NodeValue` + `node`); the
   canonical model treats them as `xsd:string` literals (`Value` + `data`).

## Decision

### 1. Vocabulary scope — Tier 1+2 (~70 operators)

Implement the core and important-advanced operators needed for a fully usable WOQL
surface. Defer specialized families to v0.3.2+:

- **Included (v0.3.1):** logical combinators (`not`, `opt`, `once`, `immediately`);
  query modifiers (`distinct`, `limit`, `start`, `order_by`, `group_by`, `count`,
  `collect`, `star`, `all`); graph patterns (`quad`, `added/removed_triple/quad`,
  `add/delete_triple/quad`, `update_triple/quad`); comparison (`less`, `greater`,
  `gte`, `lte`, `like`); schema (`isa`, `sub`, `cast`); arithmetic (`eval`, `plus`,
  `minus`, `times`, `divide`, `div`, `exp`, `floor`, `sum`); string (`concat`, `join`,
  `substr`, `trim`, `upper`, `lower`, `pad`, `split`, `length`, `regexp`); list/set
  (`dot`, `member`, `slice`, 5 set ops); path; ID generation (`unique`, `idgen`,
  `idgen_random`); documents (`insert_document`, `update_document`, `delete_document`);
  graph context (`using`, `from`, `into`, `comment`); graph meta (`size`,
  `triple_count`); literal helpers (`var`, `iri`, `string`, `boolean`, `datetime`,
  `date`, `literal`, `true`).
- **Deferred (v0.3.2+):** temporal/Allen family (19 ops); RDF list library
  (`WOQLLibrary.rdflist_*`, 17 macros); CSV/IO (`get`, `put`, `woql_as`, `file`,
  `remote`, `post`); `graph/1` context setter; macro sugar layer; range query family.

### 2. Four-wrapper value model

Adopt the canonical four-wrapper model. Each wrapper has a distinct `@type` and valid
fields:

| Wrapper | Variable | Node | Literal | Used for |
| --- | --- | --- | --- | --- |
| `NodeValue` | `{"@type":"NodeValue","variable":n}` | `{"@type":"NodeValue","node":iri}` | — | subjects, predicates, identifiers, `sub` parent/child, `iri()` |
| `Value` | `{"@type":"Value","variable":n}` | `{"@type":"Value","node":…}` | `{"@type":"Value","data":{…}}` | `triple` object, comparison operands, `read_document` document, `type_of` value, `dot`/`cast` results |
| `DataValue` | `{"@type":"DataValue","variable":n}` | — | `{"@type":"DataValue","data":{…}}` | string-op operands, `idgen`/`unique` keys & base |
| `ArithmeticValue` | `{"@type":"ArithmeticValue","variable":n}` | — | `{"@type":"ArithmeticValue","data":{…}}` | arithmetic operands |

Variables keep the `"v:Name"` prefix convention (matches Python and v0.1).

### 3. `read_document` field ordering

Swap to match the canonical model: `iri → "identifier"` (NodeValue),
`output_var → "document"` (Value).

### 4. `triple` object encoding

Align with Python: constant string objects encode as `Value` with `xsd:string` data.
Users pass `iri("...")` (new helper) when they need an IRI object. This is a minor
breaking change documented in the CHANGELOG with the `iri/1` migration path.

### 5. Quad encoding

Quads reuse the triple `@type`s (`Triple`/`AddTriple`/`DeleteTriple`/`AddedTriple`/
`DeletedTriple`) plus a `graph` field. No separate `Quad` wire type.

### 6. `float` xsd type

Standardize on `xsd:decimal` for floats in the query builder (matches the wire format
Python actually emits).

### 7. Dual path DSL

Provide both a string-compiled parser (`path("v:S", "<friend*{1,3}", "v:O")`) and
structured builders (`path_star/1`, `path_plus/1`, `path_times/3`, `path_seq/1`,
`path_or/1`, `path_inverse/1`, `path_pred/1`, `path_any/0`). The parser is built on
top of the structured builders to avoid duplicating the serializer.

### 8. `order_by` dual form

Accept both a tuple list (`[{"v:Time", :asc}, {"v:Name", :desc}]`) and a keyword list
(`[time: :asc, name: :desc]`), normalized internally to `OrderTemplate` children.

### 9. Module split

Split `woql.ex` into sub-modules (following the `Client.Params` pattern) to keep files
manageable:

```
lib/terminus_db/woql.ex           # public API, execute, to_jsonld/from_jsonld, moduledoc
lib/terminus_db/woql/encoder.ex   # 4-wrapper encoder
lib/terminus_db/woql/decoder.ex   # JSON-LD → Query struct
lib/terminus_db/woql/path.ex      # path pattern parser + structured builders
lib/terminus_db/woql/literal.ex   # value/literal helpers
```

### 10. Deferred decisions

- **`graph/1` context setter:** deferred to v0.3.2. The functional DSL has no cursor
  state; `quad/4`'s explicit graph arg covers the real use cases.
- **`Var` structured type:** keep `"v:Name"` strings as primary; `var/1` helper
  returns the string. Skip `VarsUnique` (used only by `localize()`/RDF list library).
- **Rollup/normalization:** skip. The functional builder only produces well-formed
  queries, so the degenerate-`And`/`Or` collapsing Python does in `to_dict()` is
  unnecessary.
- **Macro sugar layer:** deferred (per ADR-0002). Keep v0.3.1 purely functional.
- **Server tolerance:** the integration suite is the gate for wrapper-variation
  correctness (notably the `triple` object encoding and `read_document` field swap).

## Consequences

- **+** Wire-correct encoding for arithmetic, string, and all Tier 1+2 operators.
- **+** Full WOQL surface for real-world queries; matches Python/JS client capability.
- **+** Dual path DSL serves both TerminusDB-vested users (string patterns) and
  Elixir-idiomatic users (structured builders).
- **−** Minor breaking change: `triple` object encoding and `read_document` field
  ordering. Documented in CHANGELOG with `iri/1` migration path.
- **−** Larger module surface (5 files vs 1); mitigated by the `Client.Params` pattern
  already established in the codebase.

## Alternatives

- **Keep the 2-wrapper model** — rejected: arithmetic and several ops cannot be encoded
  correctly without `ArithmeticValue` and `Value`.
- **Implement all ~120 operators** — rejected: temporal/Allen, RDF list library, and
  CSV/IO are specialized; deferring them keeps the release focused and shippable.
- **String-only path DSL** — rejected: structured builders are more idiomatic Elixir
  and avoid a parser for programmatic construction; providing both costs little extra
  since the parser builds on the structured ops.
