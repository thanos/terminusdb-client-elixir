defmodule TerminusDB.Merge do
  @moduledoc """
  Branch merge API for TerminusDB.

  Wraps the `/api/rebase` endpoint to merge (rebase) a source branch into a target
  branch. TerminusDB uses a rebase model: the source branch's commits are
  replayed on top of the target branch, creating a linear history.

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")
        |> TerminusDB.Config.with_database("mydb")

      # Merge `feature` into `main`
      {:ok, result} = TerminusDB.Merge.merge(config,
        source_branch: "feature",
        target_branch: "main"
      )

  """

  alias TerminusDB.{Client, Config, Error}

  @type merge_opt ::
          {:source_branch, String.t()}
          | {:target_branch, String.t()}
          | {:organization, String.t()}
          | {:repo, String.t()}
          | {:author, String.t()}
          | {:message, String.t()}

  defp build_resource(config, branch, opts) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    "#{org}/#{db}/#{repo}/branch/#{branch}"
  end

  defp rebase_path(config, opts) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    target = opts[:target_branch] || config.branch
    "rebase/#{org}/#{db}/#{repo}/branch/#{target}"
  end

  defp rebase_body(config, opts) do
    source_branch = Keyword.fetch!(opts, :source_branch)
    source = build_resource(config, source_branch, opts)
    author = opts[:author] || "admin"
    message = opts[:message] || "rebase #{source_branch}"

    %{
      "author" => author,
      "message" => message,
      "rebase_from" => source
    }
  end

  @doc """
  Merges (rebases) the `source_branch` into the `target_branch`.

  TerminusDB replays the source branch's commits on top of the target branch.
  If there are conflicts, the operation returns an error describing them.

  ## Options

  - `:source_branch` (required) - the branch to merge from.
  - `:target_branch` - the branch to merge into (default: `config.branch`).
  - `:organization` - overrides `config.organization`.
  - `:repo` - overrides `config.repo`.
  - `:author` - commit author for the merge commit.
  - `:message` - commit message for the merge commit.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, result} = TerminusDB.Merge.merge(config,
      ...>   source_branch: "feature",
      ...>   target_branch: "main"
      ...> )
      iex> result["api:status"]
      "api:success"

  """
  @spec merge(Config.t(), [merge_opt()]) :: {:ok, map()} | {:error, Error.t()}
  def merge(config, opts \\ []) do
    path = rebase_path(config, opts)
    body = rebase_body(config, opts)
    Client.request(config, :post, path, json: body, area: :merge)
  end

  @doc """
  Merges branches, or raises `TerminusDB.Error`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Merge.merge!(config, source_branch: "feature", target_branch: "main")
      %{"api:status" => "api:success"}

  """
  @spec merge!(Config.t(), [merge_opt()]) :: map()
  def merge!(config, opts \\ []) do
    case merge(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end
end
