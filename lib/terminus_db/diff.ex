defmodule TerminusDB.Diff do
  @moduledoc """
  Document diff API for TerminusDB.

  Wraps the `/api/diff` endpoint to compare two document states and return a
  structured JSON patch describing the differences.

  Diffs can be computed between:
  - Two document values (`before` and `after` maps).
  - Branch vs branch, commit vs commit, or branch vs commit (by supplying the
    appropriate resource refs in the `before`/`after` fields).

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")
        |> TerminusDB.Config.with_database("mydb")

      # Diff two document values
      {:ok, patch} = TerminusDB.Diff.compare(config,
        before: %{"@id" => "Person/Alice", "name" => "Alice"},
        after: %{"@id" => "Person/Alice", "name" => "Alicia"}
      )

  """

  alias TerminusDB.{Client, Config, Error}

  @type compare_opt ::
          {:before, map()}
          | {:after, map()}
          | {:keep, map()}
          | {:organization, String.t()}
          | {:repo, String.t()}
          | {:branch, String.t()}

  defp diff_path(config, opts) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    "diff/#{org}/#{db}"
  end

  @doc """
  Compares two document states and returns a structured diff patch.

  The `before` and `after` values can be:
  - Document maps (with `@id` and fields) for a value-level diff.
  - Resource references (e.g. `"admin/mydb/local/branch/main"`) for a
    branch/commit-level diff.

  ## Options

  - `:before` (required) — the "before" document or resource ref.
  - `:after` (required) — the "after" document or resource ref.
  - `:keep` — a map of fields to preserve in the diff (e.g. `%{"@id" => true}`).
  - `:organization` — overrides `config.organization`.

  ## Examples

  Diff two document values:

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"name" => %{"@op" => "ValueSwap", "@before" => "Alice", "@after" => "Alicia"}})}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, patch} = TerminusDB.Diff.compare(config,
      ...>   before: %{"@id" => "Person/Alice", "name" => "Alice"},
      ...>   after: %{"@id" => "Person/Alice", "name" => "Alicia"}
      ...> )
      iex> patch["name"]["@op"]
      "ValueSwap"

  Diff two branches:

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, _} = TerminusDB.Diff.compare(config,
      ...>   before: "admin/mydb/local/branch/main",
      ...>   after: "admin/mydb/local/branch/feature"
      ...> )
      :ok

  """
  @spec compare(Config.t(), [compare_opt()]) :: {:ok, map()} | {:error, Error.t()}
  def compare(config, opts \\ []) do
    path = diff_path(config, opts)

    before_value = Keyword.fetch!(opts, :before)
    after_value = Keyword.fetch!(opts, :after)

    body = maybe_put(%{"before" => before_value, "after" => after_value}, "keep", opts[:keep])

    Client.request(config, :post, path, json: body, area: :diff)
  end

  @doc """
  Compares two document states, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"name" => %{"@op" => "ValueSwap"}})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Diff.compare!(config,
      ...>   before: %{"name" => "Alice"},
      ...>   after: %{"name" => "Alicia"}
      ...> )
      %{"name" => %{"@op" => "ValueSwap"}}

  """
  @spec compare!(Config.t(), [compare_opt()]) :: map()
  def compare!(config, opts \\ []) do
    case compare(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
