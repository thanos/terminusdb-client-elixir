defmodule TerminusDB do
  @moduledoc """
  An idiomatic Elixir client for [TerminusDB](https://terminusdb.org), the document
  graph database with built-in version control.

  The client provides an immutable `TerminusDB.Config` for connection context, a
  Req-based `TerminusDB.Client` HTTP layer, a typed `TerminusDB.Error`, the
  `TerminusDB.Database` management API, `TerminusDB.Document` CRUD with streaming,
  `TerminusDB.Schema` frame retrieval, `TerminusDB.Branch` management,
  `TerminusDB.Commit` history, `TerminusDB.Diff`, `TerminusDB.Merge` (rebase),
  a `TerminusDB.WOQL` functional query DSL, and `TerminusDB.Telemetry` events on
  every operation. Connection context is **immutable data**, making it safe for
  concurrent use.

  Ecto and ExDatalog integrations are planned for later milestones. See
  `ARCHITECTURE.md` and the ADRs (under `docs/adr/`) for the full design and
  roadmap.

  ## Quick start

      # 1. Configure a connection (immutable context)
      config = TerminusDB.Config.new(endpoint: "http://localhost:6363")

      # 2. Manage databases
      {:ok, _} = TerminusDB.Database.create(config, "mydb",
        label: "My Database",
        comment: "A new database",
        schema: true
      )

      # 3. Scope to a database (for later document work)
      config = TerminusDB.Config.with_database(config, "mydb")

  All public calls return `{:ok, result}` or `{:error, %TerminusDB.Error{}}`. Each
  `!/1`-suffixed variant raises `TerminusDB.Error` instead. Every operation emits
  `:telemetry` events (see `TerminusDB.Telemetry`).
  """

  @version Mix.Project.config()[:version] || "0.0.0"

  @doc """
  Returns the library version string.

  ## Examples

      iex> String.match?(TerminusDB.version(), ~r/^\\d+\\.\\d+\\.\\d+/)
      true

  """
  @spec version() :: String.t()
  def version, do: @version
end
