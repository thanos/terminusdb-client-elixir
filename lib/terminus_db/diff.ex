defmodule TerminusDB.Diff do
  import Kernel, except: [apply: 2]

  @moduledoc """
  Document diff and patch API for TerminusDB.

  Wraps the `/api/diff`, `/api/patch`, and `/api/apply` endpoints to compare,
  patch, and apply document changes.

  Diffs can be computed between:
  - Two document values (`before` and `after` maps).
  - Branch vs branch, commit vs commit, or branch vs commit (by supplying the
    appropriate resource refs in the `before`/`after` fields).

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")
        |> TerminusDB.Config.with_database("mydb")

      # Diff two document values
      {:ok, patch} = TerminusDB.Diff.diff_object(config,
        before: %{"@id" => "Person/Alice", "name" => "Alice"},
        after: %{"@id" => "Person/Alice", "name" => "Alicia"}
      )

      # Apply a patch to a branch
      {:ok, _} = TerminusDB.Diff.patch_resource(config,
        patch: patch, message: "update name", author: "admin"
      )

  """

  alias TerminusDB.{Client, Config, Error, Patch}
  alias TerminusDB.Client.Params

  @type compare_opt ::
          {:before, map()}
          | {:after, map()}
          | {:keep, map()}
          | {:organization, String.t()}

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

  - `:before` (required) - the "before" document or resource ref.
  - `:after` (required) - the "after" document or resource ref.
  - `:keep` - a map of fields to preserve in the diff (e.g. `%{"@id" => true}`).
  - `:organization` - overrides `config.organization`.

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

    body =
      Params.maybe_put(%{"before" => before_value, "after" => after_value}, "keep", opts[:keep])

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

  @type diff_object_opt ::
          {:before, map()}
          | {:after, map()}
          | {:keep, map()}
          | {:organization, String.t()}
          | {:repo, String.t()}

  @doc """
  Diffs two concrete document objects and returns a `TerminusDB.Patch` struct.

  ## Options

  - `:before` (required) - the "before" document map.
  - `:after` (required) - the "after" document map.
  - `:keep` - a map of fields to preserve in the diff.
  - `:organization` - overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}})}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, patch} = TerminusDB.Diff.diff_object(config,
      ...>   before: %{"@id" => "Person/1", "name" => "old"},
      ...>   after: %{"@id" => "Person/1", "name" => "new"}
      ...> )
      iex> patch.content["name"]["@after"]
      "new"

  """
  @spec diff_object(Config.t(), [diff_object_opt()]) ::
          {:ok, Patch.t()} | {:error, Error.t()}
  def diff_object(config, opts \\ []) do
    path = diff_resource_path(config, opts)

    before_value = Keyword.fetch!(opts, :before)
    after_value = Keyword.fetch!(opts, :after)

    body =
      Params.maybe_put(%{"before" => before_value, "after" => after_value}, "keep", opts[:keep])

    case Client.request(config, :post, path, json: body, area: :diff) do
      {:ok, patch_content} -> {:ok, %Patch{content: patch_content}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Diffs two concrete document objects, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req ->
      ...>     {req, Req.Response.new(status: 200, body: %{"name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}})}
      ...>   end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> patch = TerminusDB.Diff.diff_object!(config,
      ...>   before: %{"name" => "old"},
      ...>   after: %{"name" => "new"}
      ...> )
      iex> patch.content["name"]["@after"]
      "new"

  """
  @spec diff_object!(Config.t(), [diff_object_opt()]) :: Patch.t()
  def diff_object!(config, opts \\ []) do
    case diff_object(config, opts) do
      {:ok, patch} -> patch
      {:error, error} -> raise error
    end
  end

  @type diff_version_opt ::
          {:before_version, String.t()}
          | {:after_version, String.t()}
          | {:organization, String.t()}
          | {:repo, String.t()}

  @doc """
  Diffs two commit/branch versions and returns a `TerminusDB.Patch` struct.

  ## Options

  - `:before_version` (required) - the before commit/branch descriptor.
  - `:after_version` (required) - the after commit/branch descriptor.
  - `:organization` - overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, patch} = TerminusDB.Diff.diff_version(config,
      ...>   before_version: "admin/mydb/local/branch/main",
      ...>   after_version: "admin/mydb/local/branch/feature"
      ...> )
      iex> patch.content
      %{}

  """
  @spec diff_version(Config.t(), [diff_version_opt()]) ::
          {:ok, Patch.t()} | {:error, Error.t()}
  def diff_version(config, opts \\ []) do
    path = diff_resource_path(config, opts)

    body = %{
      "before_data_version" => Keyword.fetch!(opts, :before_version),
      "after_data_version" => Keyword.fetch!(opts, :after_version)
    }

    case Client.request(config, :post, path, json: body, area: :diff) do
      {:ok, patch_content} -> {:ok, %Patch{content: patch_content}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Diffs two versions, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> patch = TerminusDB.Diff.diff_version!(config,
      ...>   before_version: "admin/mydb/local/branch/main",
      ...>   after_version: "admin/mydb/local/branch/feature"
      ...> )
      iex> patch.content
      %{}

  """
  @spec diff_version!(Config.t(), [diff_version_opt()]) :: Patch.t()
  def diff_version!(config, opts \\ []) do
    case diff_version(config, opts) do
      {:ok, patch} -> patch
      {:error, error} -> raise error
    end
  end

  @type patch_opt ::
          {:organization, String.t()}

  @doc """
  Applies a patch to a "before" object and returns the "after" object (no
  commit).

  ## Options

  - `:organization` - overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"@id" => "Person/1", "name" => "new"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, after_obj} = TerminusDB.Diff.patch(config,
      ...>   before: %{"@id" => "Person/1", "name" => "old"},
      ...>   patch: %{"name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}}
      ...> )
      iex> after_obj["name"]
      "new"

  """
  @spec patch(Config.t(), [patch_opt() | {:before, map()} | {:patch, map()}]) ::
          {:ok, map()} | {:error, Error.t()}
  def patch(config, opts \\ []) do
    before_value = Keyword.fetch!(opts, :before)
    patch_value = Keyword.fetch!(opts, :patch)

    body = %{"before" => before_value, "patch" => patch_value}

    Client.request(config, :post, "patch", json: body, area: :diff)
  end

  @doc """
  Applies a patch, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"name" => "new"})} end
      ...> )
      iex> TerminusDB.Diff.patch!(config,
      ...>   before: %{"name" => "old"},
      ...>   patch: %{"name" => %{"@op" => "SwapValue", "@after" => "new"}}
      ...> )
      %{"name" => "new"}

  """
  @spec patch!(Config.t(), [patch_opt() | {:before, map()} | {:patch, map()}]) :: map()
  def patch!(config, opts \\ []) do
    case patch(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @type patch_resource_opt ::
          {:patch, map()}
          | {:message, String.t()}
          | {:author, String.t()}
          | {:match_final_state, boolean()}
          | {:organization, String.t()}
          | {:repo, String.t()}

  @doc """
  Applies a patch to a branch resource (commits the change).

  ## Options

  - `:patch` (required) - the patch content.
  - `:message` - commit message.
  - `:author` - commit author.
  - `:match_final_state` - boolean.
  - `:organization` - overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Diff.patch_resource(config,
      ...>   patch: %{"name" => %{"@op" => "SwapValue", "@after" => "new"}},
      ...>   author: "admin", message: "update"
      ...> )
      iex> resp["api:status"]
      "api:success"

  """
  @spec patch_resource(Config.t(), [patch_resource_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def patch_resource(config, opts \\ []) do
    path = patch_resource_path(config, opts)
    patch_value = Keyword.fetch!(opts, :patch)

    body =
      %{"patch" => patch_value}
      |> Params.maybe_put("message", opts[:message])
      |> Params.maybe_put("author", opts[:author])
      |> Params.maybe_put("match_final_state", opts[:match_final_state])

    Client.request(config, :post, path, json: body, area: :diff)
  end

  @doc """
  Applies a patch to a branch resource, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Diff.patch_resource!(config, patch: %{})
      %{"api:status" => "api:success"}

  """
  @spec patch_resource!(Config.t(), [patch_resource_opt()]) :: map()
  def patch_resource!(config, opts \\ []) do
    case patch_resource(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @type apply_opt ::
          {:before_version, String.t()}
          | {:after_version, String.t()}
          | {:message, String.t()}
          | {:author, String.t()}
          | {:organization, String.t()}
          | {:repo, String.t()}

  @doc """
  Diffs two commits and applies the changes onto a branch.

  ## Options

  - `:before_version` (required) - the before commit descriptor.
  - `:after_version` (required) - the after commit descriptor.
  - `:message` - commit message.
  - `:author` - commit author.
  - `:organization` - overrides `config.organization`.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Diff.apply(config,
      ...>   before_version: "admin/mydb/local/commit/abc",
      ...>   after_version: "admin/mydb/local/commit/def",
      ...>   author: "admin", message: "apply"
      ...> )
      iex> resp["api:status"]
      "api:success"

  """
  @spec apply(Config.t(), [apply_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def apply(config, opts \\ []) do
    path = apply_path(config, opts)

    commit_info =
      %{}
      |> Params.maybe_put("author", opts[:author])
      |> Params.maybe_put("message", opts[:message])

    body =
      Params.maybe_put(
        %{
          "before_commit" => Keyword.fetch!(opts, :before_version),
          "after_commit" => Keyword.fetch!(opts, :after_version)
        },
        "commit_info",
        commit_info
      )

    Client.request(config, :post, path, json: body, area: :diff)
  end

  @doc """
  Applies a diff to a branch, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Diff.apply!(config,
      ...>   before_version: "admin/mydb/local/commit/abc",
      ...>   after_version: "admin/mydb/local/commit/def"
      ...> )
      %{"api:status" => "api:success"}

  """
  @spec apply!(Config.t(), [apply_opt()]) :: map()
  def apply!(config, opts \\ []) do
    case apply(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  defp diff_resource_path(config, opts) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    branch = config.branch
    "diff/#{org}/#{db}/#{repo}/branch/#{branch}"
  end

  defp patch_resource_path(config, opts) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    branch = config.branch
    "patch/#{org}/#{db}/#{repo}/branch/#{branch}"
  end

  defp apply_path(config, opts) do
    org = opts[:organization] || config.organization
    db = config.database || raise Error, reason: :http, message: "no database scoped in config"
    repo = opts[:repo] || config.repo
    branch = config.branch
    "apply/#{org}/#{db}/#{repo}/branch/#{branch}"
  end
end
