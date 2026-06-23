# ADR-0003: Ecto integration via `TerminusDB.Schema` macro

Date: 2026-06-23
Status: Accepted (implementation in v0.3)

## Context

Users want to model TerminusDB documents as Elixir structs with typed fields and
changeset validation, and to generate TerminusDB schema definitions from those structs.
Ecto provides the idiomatic `Ecto.Schema` + `Ecto.Changeset` primitives. The
`mongodb_driver` Ecto integration demonstrates that a non-SQL store can sit beneath
Ecto-style schemas.

A full `Ecto.Adapter` (so `Repo` works against TerminusDB) is a much larger undertaking
and is not required for the initial release.

## Decision

Deliver Ecto integration in three phases:

1. **Phase 1 (v0.3):** `use TerminusDB.Schema` — a thin macro over `Ecto.Schema` that
   annotates the struct with TerminusDB metadata (document `@type`, key strategy) and
   provides changeset helpers. Ecto is an **optional dependency** enabled via
   `{:terminusdb_client, "~> 0.x", optional: true}` + `:ecto` compile flag.

   ```elixir
   defmodule MyApp.Person do
     use TerminusDB.Schema

     schema "Person" do
       field :name, :string
       field :age, :integer
     end
   end
   ```

2. **Phase 2 (v0.3):** `TerminusDB.Schema.to_terminus_schema/1` generates the TerminusDB
   schema JSON-LD document(s) from a `TerminusDB.Schema` module, for submission via the
   document/schema API.

3. **Phase 3 (research, post-v0.3):** Evaluate a full `TerminusDB.Ecto.Adapter`. Document
   feasibility/limits; an adapter is **not** required for v0.x.

## Consequences

- **+** Users get typed structs + changesets, the most valuable part of Ecto, cheaply.
- **+** Optional dep keeps the core library light for users who only want the HTTP API.
- **+** Phase 1/2 are high-value, low-risk; the adapter (hard part) is deferred and de-risked.
- **−** Mapping Ecto types to TerminusDB/XSD types needs a table (`:string`→`xsd:string`,
  `:integer`→`xsd:integer`, `:decimal`→`xsd:decimal`, `:datetime`→`xsd:dateTime`, …) and
  handling of `@key` strategies and object/document references.
- **−** A full adapter may prove infeasible for parts of Ecto's query model (e.g. complex
  joins) — documented as a known limitation in Phase 3.

## Alternatives

- **No Ecto, hand-rolled struct DSL** — reinvents changesets/validation. Rejected; Ecto is
  the Elixir standard.
- **Full adapter from day one** — too large, blocks the release. Rejected for v0.x.
