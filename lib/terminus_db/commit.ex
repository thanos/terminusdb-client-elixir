defmodule TerminusDB.Commit do
  @moduledoc """
  Commit history and inspection API for TerminusDB.

  Every write to TerminusDB creates an immutable commit. Commits form a chain
  (per branch) that gives the full history of the database. This module wraps
  the history/log endpoints to traverse and inspect commits.

  All functions require a `TerminusDB.Config` scoped to a database (via
  `TerminusDB.Config.with_database/2`). The branch defaults to `config.branch`
  but can be overridden per call via the `:branch` option.

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")
        |> TerminusDB.Config.with_database("mydb")

      # List recent commits on the current branch
      {:ok, log} = TerminusDB.Commit.log(config)

      # Full history with commit metadata
      {:ok, history} = TerminusDB.Commit.history(config)

      # Inspect a specific commit
      {:ok, commit} = TerminusDB.Commit.get(config, "commit/abc123")

  """

  alias TerminusDB.{Client, Config, Error}
  alias TerminusDB.Client.Params

  @type commit_opt ::
          {:branch, String.t()}
          | {:repo, String.t()}
          | {:organization, String.t()}
          | {:start, String.t()}
          | {:limit, pos_integer()}
          | {:count, pos_integer()}

  defp commit_path(config, opts, resource) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    branch = opts[:branch] || config.branch
    "#{resource}/#{org}/#{db}/#{repo}/branch/#{branch}"
  end

  @doc """
  Returns a concise log of recent commits on the current (or given) branch.

  Each entry includes the commit ID, author, message, and timestamp.

  ## Options

  - `:branch` - overrides `config.branch`.
  - `:repo` - overrides `config.repo`.
  - `:organization` - overrides `config.organization`.
  - `:start` - a commit ID to start listing from (for pagination).
  - `:limit` - max number of commits to return.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: [
      ...>       %{"commit" => "commit/abc", "author" => "admin", "message" => "add Alice", "timestamp" => "2026-06-24T10:00:00Z"}
      ...>     ])}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, log} = TerminusDB.Commit.log(config)
      iex> hd(log)["author"]
      "admin"

  """
  @spec log(Config.t(), [commit_opt()]) :: {:ok, [map()]} | {:error, Error.t()}
  def log(config, opts \\ []) do
    path = commit_path(config, opts, "log")

    params =
      Params.flag_param(:start, opts[:start]) ++
        Params.flag_param(:limit, opts[:limit]) ++
        Params.flag_param(:count, opts[:count])

    Client.request(config, :get, path, params: params, area: :commit)
  end

  @doc """
  Returns a concise log of commits, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"commit" => "c1"}])} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Commit.log!(config)
      [%{"commit" => "c1"}]

  """
  @spec log!(Config.t(), [commit_opt()]) :: [map()]
  def log!(config, opts \\ []) do
    case log(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Returns the full commit history for the current (or given) branch.

  This is an alias for `log/2` - both use the same `/api/log` endpoint with
  the same parameters. Provided as a semantically distinct name for callers
  building history viewers or audit trails.

  ## Options

  Same as `log/2`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: [
      ...>       %{"@id" => "commit/abc", "author" => "admin", "message" => "init", "timestamp" => 1782350430.12}
      ...>     ])}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, history} = TerminusDB.Commit.history(config)
      iex> is_list(history)
      true

  """
  @spec history(Config.t(), [commit_opt()]) :: {:ok, [map()]} | {:error, Error.t()}
  def history(config, opts \\ []) do
    log(config, opts)
  end

  @doc """
  Returns the full commit history, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: [%{"commit" => "c1"}])} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Commit.history!(config)
      [%{"commit" => "c1"}]

  """
  @spec history!(Config.t(), [commit_opt()]) :: [map()]
  def history!(config, opts \\ []) do
    case history(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Retrieves a single commit by its descriptor ID (e.g. `"commit/abc123"`).

  Returns the commit object with its metadata: author, message, timestamp,
  parent reference, and the schema/data references.

  ## Options

  - `:branch` - overrides `config.branch`.
  - `:repo` - overrides `config.repo`.
  - `:organization` - overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"@id" => "commit/abc", "author" => "admin", "message" => "add Alice"}}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, commit} = TerminusDB.Commit.get(config, "commit/abc")
      iex> commit["author"]
      "admin"

  """
  @spec get(Config.t(), String.t(), [commit_opt()]) :: {:ok, map()} | {:error, Error.t()}
  def get(config, commit_id, opts \\ []) do
    org = opts[:organization] || config.organization

    db =
      config.database ||
        raise Error, reason: :http, message: "no database scoped in config"

    repo = opts[:repo] || config.repo
    branch = opts[:branch] || config.branch
    path = "history/#{org}/#{db}/#{repo}/branch/#{branch}/#{commit_id}"

    Client.request(config, :get, path, area: :commit)
  end

  @doc """
  Retrieves a single commit, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"@id" => "commit/abc", "author" => "admin"}} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Commit.get!(config, "commit/abc")
      %{"@id" => "commit/abc", "author" => "admin"}

  """
  @spec get!(Config.t(), String.t(), [commit_opt()]) :: map()
  def get!(config, commit_id, opts \\ []) do
    case get(config, commit_id, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end
end
