# ADR-0001: Use Req as the HTTP client

Date: 2026-06-23
Status: Accepted

## Context

`terminusdb_ex` needs an HTTP client to talk to the TerminusDB REST API over JSON.
The client must support: basic + bearer auth, JSON request/response bodies, query
params, retries on transient errors, response streaming (for large document lists),
and ergonomic testing without a live server.

Candidate libraries: Req, Tesla, raw Finch, Erlang's `:httpc`.

## Decision

Use **Req** (~> 0.5) as the HTTP client, with **Jason** (Req's default decoder) for JSON.

## Consequences

- **+** Batteries-included: JSON encoding/decoding, params, auth, retry, redirects are
  built-in steps — we write almost no plumbing.
- **+** Streaming via `into: :self` / `into: collectable` / `into: fun` directly supports
  the streaming requirement (ADR-0007) with no extra dependency.
- **+** Testability: Req's fake `adapter: fn request -> {request, response} end` lets unit
  tests assert requests and stub responses without touching the network (ADR-0006).
- **+** Built on Finch → production-grade pooling and HTTP/1+HTTP/2.
- **−** Couples us to Req's option shape; a future migration would touch `Client` only
  (the single wire module), so the blast radius is small.
- **−** Adds `req` + transitive `finch`/`mint`/`jason`/`castore` to the dep tree. These are
  ubiquitous, well-maintained Hex packages — acceptable for a client library.

## Alternatives

- **Tesla** — equally capable but delegates adapter + JSON + retry selection to the user,
  adding configuration surface. Req's defaults are better for a focused client.
- **Raw Finch** — would require reimplementing Req's steps (JSON, params, retry, auth).
  Not worth it.
- **`:httpc`** — no streaming, awkward JSON, no pooling. Rejected.
