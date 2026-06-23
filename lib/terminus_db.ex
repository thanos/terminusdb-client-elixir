defmodule TerminusDB do
  @moduledoc """
  A modern, idiomatic Elixir client for [TerminusDB](https://terminusdb.org) — the
  document graph database with built-in version control.

  `terminusdb_ex` exposes database management, document/schema APIs, WOQL, GraphQL,
  telemetry, and streaming, with optional Ecto and ExDatalog integration. It is built
  on `Req` and treats connection context as **immutable data**, making it safe for
  concurrent use.

  ## Quick start

      # 1. Configure a connection (immutable context)
      config = TerminusDB.Config.new(endpoint: "http://localhost:6363")

      # 2. Manage databases
      {:ok, _} = TerminusDB.Database.create(config, "mydb",
        label: "My Database",
        comment: "A new database",
        schema: true
      )

      # 3. Scope to a database and work with documents (v0.2)
      config = TerminusDB.Config.with_database(config, "mydb")

  All public calls return `{:ok, result}` or `{:error, %TerminusDB.Error{}}`. Each
  `!/1`-suffixed variant raises `TerminusDB.Error` instead. Every operation emits
  `:telemetry` events (see `TerminusDB.Telemetry`).

  ## Architecture

  See `ARCHITECTURE.md` and the ADRs (under `docs/adr/`) for the full design, including the
  HTTP client selection (Req), the WOQL DSL, Ecto/ExDatalog integration strategies,
  telemetry, testing, and streaming.
  """

  @doc """
  Returns the library version string.

  ## Examples

      iex> String.match?(TerminusDB.version(), ~r/^\\d+\\.\\d+\\.\\d+/)
      true

  """
  @spec version() :: String.t()
  def version, do: "0.1.0"
end
