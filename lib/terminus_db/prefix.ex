defmodule TerminusDB.Prefix do
  @moduledoc """
  Prefix management API for TerminusDB.

  Wraps the `/api/prefix/{path}` and `/api/prefixes/{path}` endpoints for
  managing custom prefix mappings in a database.

  All functions require a `TerminusDB.Config` scoped to a database.

  ## Quick start

      config =
        TerminusDB.Config.new(endpoint: "http://localhost:6363")
        |> TerminusDB.Config.with_database("mydb")

      {:ok, uri} = TerminusDB.Prefix.get(config, "ex")
      {:ok, _} = TerminusDB.Prefix.add(config, "ex", "http://example.org/")
      {:ok, _} = TerminusDB.Prefix.update(config, "ex", "http://example.com/")
      {:ok, _} = TerminusDB.Prefix.delete(config, "ex")

  """

  alias TerminusDB.{Client, Config, Error}

  @type prefix_opt :: {:organization, String.t()} | {:repo, String.t()}

  defp prefix_base_path(config, opts) do
    org = opts[:organization] || config.organization

    case config.database do
      nil ->
        {:error, %Error{reason: :config, message: "no database scoped in config"}}

      db ->
        repo = opts[:repo] || config.repo
        branch = config.branch
        {:ok, "prefix/#{org}/#{db}/#{repo}/branch/#{branch}"}
    end
  end

  defp prefixes_path(config, opts) do
    org = opts[:organization] || config.organization

    case config.database do
      nil -> {:error, %Error{reason: :config, message: "no database scoped in config"}}
      db -> {:ok, "prefixes/#{org}/#{db}"}
    end
  end

  @doc """
  Gets a single prefix IRI by name.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:prefix_uri" => "http://example.org/"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, uri} = TerminusDB.Prefix.get(config, "ex")
      iex> uri
      "http://example.org/"

  """
  @spec get(Config.t(), String.t(), [prefix_opt()]) :: {:ok, String.t()} | {:error, Error.t()}
  def get(config, prefix_name, opts \\ []) do
    with {:ok, base} <- prefix_base_path(config, opts) do
      path = "#{base}/#{prefix_name}"

      case Client.request(config, :get, path, area: :prefix) do
        {:ok, %{"api:prefix_uri" => uri}} -> {:ok, uri}
        {:ok, body} -> {:ok, body}
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Gets a single prefix IRI by name, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:prefix_uri" => "http://example.org/"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Prefix.get!(config, "ex")
      "http://example.org/"

  """
  @spec get!(Config.t(), String.t(), [prefix_opt()]) :: String.t()
  def get!(config, prefix_name, opts \\ []) do
    case get(config, prefix_name, opts) do
      {:ok, uri} -> uri
      {:error, error} -> raise error
    end
  end

  @doc """
  Adds a new prefix mapping.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Prefix.add(config, "ex", "http://example.org/")
      iex> resp["api:status"]
      "api:success"

  """
  @spec add(Config.t(), String.t(), String.t(), [prefix_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def add(config, prefix_name, uri, opts \\ []) do
    with {:ok, base} <- prefix_base_path(config, opts) do
      path = "#{base}/#{prefix_name}"
      Client.request(config, :post, path, json: %{"uri" => uri}, area: :prefix)
    end
  end

  @doc """
  Adds a new prefix mapping, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Prefix.add!(config, "ex", "http://example.org/")
      %{"api:status" => "api:success"}

  """
  @spec add!(Config.t(), String.t(), String.t(), [prefix_opt()]) :: map()
  def add!(config, prefix_name, uri, opts \\ []) do
    case add(config, prefix_name, uri, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Updates an existing prefix mapping.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Prefix.update(config, "ex", "http://example.com/")
      iex> resp["api:status"]
      "api:success"

  """
  @spec update(Config.t(), String.t(), String.t(), [prefix_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def update(config, prefix_name, uri, opts \\ []) do
    with {:ok, base} <- prefix_base_path(config, opts) do
      path = "#{base}/#{prefix_name}"
      Client.request(config, :put, path, json: %{"uri" => uri}, area: :prefix)
    end
  end

  @doc """
  Updates an existing prefix mapping, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Prefix.update!(config, "ex", "http://example.com/")
      %{"api:status" => "api:success"}

  """
  @spec update!(Config.t(), String.t(), String.t(), [prefix_opt()]) :: map()
  def update!(config, prefix_name, uri, opts \\ []) do
    case update(config, prefix_name, uri, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Creates or updates a prefix mapping (upsert).

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Prefix.upsert(config, "ex", "http://example.org/")
      iex> resp["api:status"]
      "api:success"

  """
  @spec upsert(Config.t(), String.t(), String.t(), [prefix_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def upsert(config, prefix_name, uri, opts \\ []) do
    with {:ok, base} <- prefix_base_path(config, opts) do
      path = "#{base}/#{prefix_name}"

      Client.request(config, :put, path,
        json: %{"uri" => uri},
        params: [create: true],
        area: :prefix
      )
    end
  end

  @doc """
  Creates or updates a prefix mapping (upsert), or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Prefix.upsert!(config, "ex", "http://example.org/")
      %{"api:status" => "api:success"}

  """
  @spec upsert!(Config.t(), String.t(), String.t(), [prefix_opt()]) :: map()
  def upsert!(config, prefix_name, uri, opts \\ []) do
    case upsert(config, prefix_name, uri, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Deletes a prefix mapping.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, resp} = TerminusDB.Prefix.delete(config, "ex")
      iex> resp["api:status"]
      "api:success"

  """
  @spec delete(Config.t(), String.t(), [prefix_opt()]) ::
          {:ok, map()} | {:error, Error.t()}
  def delete(config, prefix_name, opts \\ []) do
    with {:ok, base} <- prefix_base_path(config, opts) do
      path = "#{base}/#{prefix_name}"
      Client.request(config, :delete, path, area: :prefix)
    end
  end

  @doc """
  Deletes a prefix mapping, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"api:status" => "api:success"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Prefix.delete!(config, "ex")
      %{"api:status" => "api:success"}

  """
  @spec delete!(Config.t(), String.t(), [prefix_opt()]) :: map()
  def delete!(config, prefix_name, opts \\ []) do
    case delete(config, prefix_name, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  @doc """
  Gets all prefix mappings for the database.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"@base" => "terminusdb:///data/", "@schema" => "terminusdb:///schema#"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> {:ok, prefixes} = TerminusDB.Prefix.all(config)
      iex> prefixes["@schema"]
      "terminusdb:///schema#"

  """
  @spec all(Config.t(), [prefix_opt()]) :: {:ok, map()} | {:error, Error.t()}
  def all(config, opts \\ []) do
    with {:ok, path} <- prefixes_path(config, opts) do
      Client.request(config, :get, path, area: :prefix)
    end
  end

  @doc """
  Gets all prefix mappings, or raises.

  ## Examples

      iex> config = TerminusDB.Config.new(
      ...>   endpoint: "http://localhost:6363",
      ...>   adapter: fn req -> {req, Req.Response.new(status: 200, body: %{"@base" => "terminusdb:///data/", "@schema" => "terminusdb:///schema#"})} end
      ...> ) |> TerminusDB.Config.with_database("mydb")
      iex> TerminusDB.Prefix.all!(config)["@schema"]
      "terminusdb:///schema#"

  """
  @spec all!(Config.t(), [prefix_opt()]) :: map()
  def all!(config, opts \\ []) do
    case all(config, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end
end
