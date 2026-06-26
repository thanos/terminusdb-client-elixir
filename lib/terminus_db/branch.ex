defmodule TerminusDB.Branch do
  @moduledoc """
  Branch management API for TerminusDB.

  Wraps the `/api/branch/{path}` endpoints. Branches are git-like pointers to
  commits within a repository. Creating a branch forks from an existing branch
  (default: `main`).

  All functions require a `TerminusDB.Config` scoped to a database (via
  `TerminusDB.Config.with_database/2`). The organization defaults to
  `config.organization` and the repository to `config.repo` (default `local`),
  both overridable per call.

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")
        |> TerminusDB.Config.with_database("mydb")

      # Create a branch (forks from main by default)
      {:ok, _} = TerminusDB.Branch.create(config, "feature")

      # Check it exists
      true = TerminusDB.Branch.exists?(config, "feature")

      # Delete it
      {:ok, _} = TerminusDB.Branch.delete(config, "feature")

  """

  alias TerminusDB.{Client, Config, Error}
  alias TerminusDB.Client.Params

  @type branch_opt ::
          {:organization, String.t()}
          | {:repo, String.t()}
          | {:from, String.t()}
          | {:author, String.t()}
          | {:message, String.t()}

  defp branch_path(config, branch_name, opts) do
    repo = opts[:repo] || config.repo
    "branch/#{Client.resource_path(config, opts)}/#{repo}/branch/#{branch_name}"
  end

  @doc """
  Creates a new branch `branch_name` in the configured (or given) repository.

  The branch is forked from the branch named in `:from` (default: `config.branch`,
  which defaults to `"main"`).

  ## Options

  - `:from` — the branch to fork from (default: `config.branch`).
  - `:organization` — overrides `config.organization`.
  - `:repo` — overrides `config.repo` (`local` or a remote name).

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Branch.create(config, "feature")
      iex> resp["api:status"]
      "api:success"

  Fork from a specific branch:

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Branch.create(config, "dev", from: "main")
      iex> resp["api:status"]
      "api:success"

  """
  @spec create(Config.t(), String.t(), [branch_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def create(config, branch_name, opts \\ []) do
    path = branch_path(config, branch_name, opts)
    org = opts[:organization] || config.organization
    repo = opts[:repo] || config.repo
    origin_branch = opts[:from] || config.branch

    body = %{
      "origin" => "#{org}/#{config.database}/#{repo}/branch/#{origin_branch}"
    }

    Client.request(config, :post, path, json: body, area: :branch)
  end

  @doc """
  Creates a branch, returning the response body or raising `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Branch.create!(config, "feature")
      %{"api:status" => "api:success"}

  """
  @spec create!(Config.t(), String.t(), [branch_opt()]) :: map()
  def create!(config, branch_name, opts \\ []) do
    case create(config, branch_name, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Deletes the branch `branch_name`.

  ## Options

  - `:organization` — overrides `config.organization`.
  - `:repo` — overrides `config.repo`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Branch.delete(config, "feature")
      iex> resp["api:status"]
      "api:success"

  """
  @spec delete(Config.t(), String.t(), [branch_opt()]) ::
          {:ok, map() | nil} | {:error, Error.t()}
  def delete(config, branch_name, opts \\ []) do
    path = branch_path(config, branch_name, opts)
    Client.request(config, :delete, path, area: :branch)
  end

  @doc """
  Deletes a branch, returning the response body or raising `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Branch.delete!(config, "feature")
      %{"api:status" => "api:success"}

  """
  @spec delete!(Config.t(), String.t(), [branch_opt()]) :: map() | nil
  def delete!(config, branch_name, opts \\ []) do
    case delete(config, branch_name, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Squashes the current branch HEAD into a single commit.

  ## Options

  - `:author` — commit author.
  - `:message` — commit message.
  - `:organization` — overrides `config.organization`.
  - `:repo` — overrides `config.repo`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success", "api:commit" => "abc123"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Branch.squash(config, author: "admin", message: "squash")
      iex> resp["api:commit"]
      "abc123"

  """
  @spec squash(Config.t(), [branch_opt()]) :: {:ok, map()} | {:error, Error.t()}
  def squash(config, opts \\ []) do
    path = squash_path(config, opts)

    commit_info =
      %{}
      |> Params.maybe_put("author", opts[:author])
      |> Params.maybe_put("message", opts[:message])

    Client.request(config, :post, path, json: %{"commit_info" => commit_info}, area: :branch)
  end

  @doc """
  Squashes the branch HEAD, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success", "api:commit" => "abc"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Branch.squash!(config, author: "admin", message: "squash")
      %{"api:commit" => "abc"}

  """
  @spec squash!(Config.t(), [branch_opt()]) :: map()
  def squash!(config, opts \\ []) do
    case squash(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Hard-resets the branch HEAD to a specific commit.

  ## Options

  - `:organization` — overrides `config.organization`.
  - `:repo` — overrides `config.repo`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Branch.reset(config, "admin/mydb/local/commit/abc123")
      iex> resp["api:status"]
      "api:success"

  """
  @spec reset(Config.t(), String.t(), [branch_opt()]) :: {:ok, map()} | {:error, Error.t()}
  def reset(config, commit_descriptor, opts \\ []) do
    path = reset_path(config, opts)

    Client.request(config, :post, path,
      json: %{"commit_descriptor" => commit_descriptor},
      area: :branch
    )
  end

  @doc """
  Hard-resets the branch HEAD, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Branch.reset!(config, "admin/mydb/local/commit/abc")
      %{"api:status" => "api:success"}

  """
  @spec reset!(Config.t(), String.t(), [branch_opt()]) :: map()
  def reset!(config, commit_descriptor, opts \\ []) do
    case reset(config, commit_descriptor, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  defp squash_path(config, opts) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    branch = config.branch
    "squash/#{org}/#{db}/#{repo}/branch/#{branch}"
  end

  defp reset_path(config, opts) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    branch = config.branch
    "reset/#{org}/#{db}/#{repo}/branch/#{branch}"
  end

  @doc """
  Returns `true` if the branch `branch_name` exists, `false` otherwise.

  Checks the database's branch list via `GET /api/db/:org/:db?branches=true`.
  A 404 on the database means it does not exist (so the branch cannot either);
  any other non-success response raises `TerminusDB.Error`.

  ## Options

  - `:organization` — overrides `config.organization`.
  - `:repo` — overrides `config.repo`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"branches" => ["main", "feature"], "path" => "admin/mydb"})}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Branch.exists?(config, "main")
      true

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"branches" => ["main"], "path" => "admin/mydb"})}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Branch.exists?(config, "missing")
      false

  """
  @spec exists?(Config.t(), String.t(), [branch_opt()]) :: boolean()
  def exists?(config, branch_name, opts \\ []) do
    org = opts[:organization] || config.organization

    db =
      config.database ||
        raise Error, reason: :http, message: "no database scoped in config"

    case Client.request(config, :get, "db/#{org}/#{db}", params: [branches: true], area: :branch) do
      {:ok, %{"branches" => branches}} ->
        branch_name in branches

      {:ok, _} ->
        false

      {:error, %Error{status: 404}} ->
        false

      {:error, error} ->
        raise error
    end
  end
end
