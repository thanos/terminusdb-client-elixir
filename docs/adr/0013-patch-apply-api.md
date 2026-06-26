# ADR-0013: Patch class and apply API

Date: 2026-06-25
Status: Accepted (implementation in v0.3.2)

## Context

The Python client has a `Patch` class for working with TerminusDB's JSON-LD
patch format (diff/patch/apply). The `diff` method is deprecated in favor of
`diff_object`, `diff_version`, `patch`, `patch_resource`, and `apply`.

The Elixir client has `TerminusDB.Diff.compare/2` but no `Patch` struct and no
patch/apply methods.

## Decision

### `TerminusDB.Patch` struct

New file: `lib/terminus_db/patch.ex`

```elixir
defstruct [:content]
```

Functions:
- `from_json/1` — parse JSON string into `%Patch{content: decoded_map}`
- `to_json/1` — serialize `%Patch{}` to JSON string
- `update/1` — extract `@after` values from `SwapValue` ops (recursive)
- `before/1` — extract `@before` values (recursive)
- `copy/1` — deep copy

### Diff module extensions

Extend `TerminusDB.Diff` with:
- `diff_object/2` — diff two concrete objects → `{:ok, %Patch{}}`
- `diff_version/2` — diff two commit/branch versions → `{:ok, %Patch{}}`
- `patch/2` — apply patch to before object (no commit) → `{:ok, after_object}`
- `patch_resource/2` — apply patch to branch resource (commits) — opts:
  `:patch`, `:message`, `:author`, `:match_final_state`
- `apply/3` — diff two commits and apply onto branch — opts:
  `:before_version`, `:after_version`, `:message`, `:author`

### Endpoints

| Method | Endpoint |
|--------|----------|
| `diff_object/2` | `POST /api/diff/{org}/{db}/{repo}/branch/{branch}` |
| `diff_version/2` | `POST /api/diff/{org}/{db}/{repo}/branch/{branch}` |
| `patch/2` | `POST /api/patch` |
| `patch_resource/2` | `POST /api/patch/{org}/{db}/{repo}/branch/{branch}` |
| `apply/3` | `POST /api/apply/{org}/{db}/{repo}/branch/{branch}` |

## Consequences

- 1 new struct, 5 new methods.
- `Diff.compare/2` is kept for backward compatibility (equivalent to
  `diff_object/2` but returns a raw map instead of `%Patch{}`).
- ~15 new unit tests.

## Alternatives considered

1. **Just extend `Diff` without a `Patch` struct** — rejected (the `Patch`
   struct provides useful projections (`update`, `before`) that are worth
   encapsulating).
2. **Defer to v0.3.3** — rejected (fills a clear gap, small scope).
