defmodule TerminusDB.Remote do
  @moduledoc """
  Remote collaboration API for TerminusDB.

  Wraps the `/api/clone`, `/api/fetch`, `/api/push`, and `/api/pull` endpoints
  for working with remote TerminusDB repositories.

  All functions require a `TerminusDB.Config` scoped to a database (except
  `clone/3` which creates a new database).

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")

      # Clone a remote database
      {:ok, _} = TerminusDB.Remote.clone(config, "https://data.terminusdb.org/public/star-wars", "star-wars",
        label: "Star Wars", comment: "Star Wars dataset")

      # Push current branch to remote
      {:ok, _} = TerminusDB.Remote.push(config, "origin", "main",
        author: "admin", message: "push changes")

  """

  alias TerminusDB.{Client, Config, Error}

  @type remote_opt ::
          {:organization, String.t()}
          | {:repo, String.t()}
          | {:label, String.t()}
          | {:comment, String.t()}
          | {:author, String.t()}
          | {:message, String.t()}
          | {:remote_branch, String.t()}
          | {:push_prefixes, boolean()}

  @doc """
  Clones a remote repository into a new local database.

  ## Options

  - `:label` — database label (defaults to `newid`).
  - `:comment` — database comment (defaults to `""`).
  - `:organization` — target organization (defaults to `config.organization`).

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> )
      iex> {:ok, resp} = TerminusDB.Remote.clone(config, "https://data.terminusdb.org/public/star-wars", "star-wars", label: "Star Wars")
      iex> resp["api:status"]
      "api:success"

  """
  @spec clone(Config.t(), String.t(), String.t(), [remote_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def clone(config, remote_url, newid, opts \\ []) do
    org = opts[:organization] || config.organization
    path = "clone/#{org}/#{newid}"

    body = %{
      "remote_url" => remote_url,
      "label" => opts[:label] || newid,
      "comment" => opts[:comment] || ""
    }

    Client.request(config, :post, path, json: body, area: :remote)
  end

  @doc """
  Clones a remote repository, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> )
      iex> TerminusDB.Remote.clone!(config, "https://data.terminusdb.org/public/star-wars", "star-wars")
      %{"api:status" => "api:success"}

  """
  @spec clone!(Config.t(), String.t(), String.t(), [remote_opt()]) :: map()
  def clone!(config, remote_url, newid, opts \\ []) do
    case clone(config, remote_url, newid, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Fetches branches from a remote repository.

  ## Options

  - `:organization` — overrides `config.organization`.
  - `:repo` — overrides `config.repo`.
  - `:remote_id` — remote repository ID (default `"origin"`).

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success", "api:head_has_changed" => true})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Remote.fetch(config)
      iex> resp["api:head_has_changed"]
      true

  """
  @spec fetch(Config.t(), [remote_opt()]) :: {:ok, map()} | {:error, Error.t()}
  def fetch(config, opts \\ []) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    branch = config.branch
    remote_id = opts[:remote_id] || "origin"

    path = "fetch/#{org}/#{db}/#{repo}/branch/#{branch}/#{remote_id}/_commits"
    Client.request(config, :post, path, area: :remote)
  end

  @doc """
  Fetches from remote, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success", "api:head_has_changed" => false})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Remote.fetch!(config)
      %{"api:head_has_changed" => false}

  """
  @spec fetch!(Config.t(), [remote_opt()]) :: map()
  def fetch!(config, opts \\ []) do
    case fetch(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Pushes the current branch to a remote repository.

  ## Options

  - `:remote` — remote name (default `"origin"`).
  - `:remote_branch` — remote branch name (default `config.branch`).
  - `:author` — commit author.
  - `:message` — commit message.
  - `:organization` — overrides `config.organization`.
  - `:repo` — overrides `config.repo`.
  - `:push_prefixes` — also push prefixes (default `false`).

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success", "api:repo_head_updated" => true})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Remote.push(config, "origin", "main", author: "admin", message: "push")
      iex> resp["api:repo_head_updated"]
      true

  """
  @spec push(Config.t(), String.t(), String.t(), [remote_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def push(config, remote, remote_branch, opts \\ []) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    branch = config.branch

    path = "push/#{org}/#{db}/#{repo}/branch/#{branch}"

    body = %{
      "remote" => remote,
      "remote_branch" => remote_branch
    }

    body =
      body
      |> maybe_put_string("author", opts[:author])
      |> maybe_put_string("message", opts[:message])

    params =
      if opts[:push_prefixes] do
        [push_prefixes: true]
      else
        []
      end

    Client.request(config, :post, path, json: body, params: params, area: :remote)
  end

  @doc """
  Pushes to remote, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success", "api:repo_head_updated" => true})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Remote.push!(config, "origin", "main")
      %{"api:repo_head_updated" => true}

  """
  @spec push!(Config.t(), String.t(), String.t(), [remote_opt()]) :: map()
  def push!(config, remote, remote_branch, opts \\ []) do
    case push(config, remote, remote_branch, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Pulls updates from a remote repository into the current branch.

  ## Options

  Same as `push/4`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Remote.pull(config, "origin", "main", author: "admin", message: "pull")
      iex> resp["api:status"]
      "api:success"

  """
  @spec pull(Config.t(), String.t(), String.t(), [remote_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def pull(config, remote, remote_branch, opts \\ []) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    branch = config.branch

    path = "pull/#{org}/#{db}/#{repo}/branch/#{branch}"

    body = %{
      "remote" => remote,
      "remote_branch" => remote_branch
    }

    body =
      body
      |> maybe_put_string("author", opts[:author])
      |> maybe_put_string("message", opts[:message])

    Client.request(config, :post, path, json: body, area: :remote)
  end

  @doc """
  Pulls from remote, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Remote.pull!(config, "origin", "main")
      %{"api:status" => "api:success"}

  """
  @spec pull!(Config.t(), String.t(), String.t(), [remote_opt()]) :: map()
  def pull!(config, remote, remote_branch, opts \\ []) do
    case pull(config, remote, remote_branch, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  defp maybe_put_string(map, _key, nil), do: map
  defp maybe_put_string(map, key, value), do: Map.put(map, key, value)
end
