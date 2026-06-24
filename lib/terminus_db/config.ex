defmodule TerminusDB.Config do
  @version Mix.Project.config()[:version] || "0.0.0"

  @schema [
    endpoint: [
      type: :string,
      required: true,
      doc: "TerminusDB server URL, e.g. `http://localhost:6363`."
    ],
    user: [
      type: :string,
      default: "admin",
      doc: "User name for HTTP Basic auth. Ignored when `:token` is set."
    ],
    key: [
      type: :string,
      default: "root",
      doc: "API key / password for HTTP Basic auth. Ignored when `:token` is set."
    ],
    token: [
      type: :string,
      doc: "Bearer token. When set, takes precedence over Basic auth (`:user`/`:key`)."
    ],
    organization: [
      type: :string,
      default: "admin",
      doc: "Organization (team) that owns the database."
    ],
    database: [
      type: :string,
      doc: "Current database name. Set with `with_database/2`."
    ],
    branch: [
      type: :string,
      default: "main",
      doc: "Current branch. Set with `with_branch/2`."
    ],
    repo: [
      type: :string,
      default: "local",
      doc: "Repository: `local` or a remote name."
    ],
    ref: [
      type: :string,
      doc: "A commit reference for time-travel queries."
    ],
    headers: [
      type: {:map, :string, :string},
      default: %{},
      doc: "Extra HTTP headers merged into every request."
    ],
    receive_timeout: [
      type: :pos_integer,
      default: 15_000,
      doc: "Socket receive timeout in milliseconds."
    ],
    telemetry: [
      type: :boolean,
      default: true,
      doc: "Whether to emit `:telemetry` events for operations."
    ],
    adapter: [
      type: :any,
      doc: """
      A Req adapter function used in place of the network. Intended for testing:
      `adapter: fn req -> {req, Req.Response.new(status: 200, body: %{})} end`.
      """
    ],
    user_agent: [
      type: :string,
      default: "terminusdb_ex/#{@version}",
      doc: "Value of the `user-agent` request header."
    ]
  ]

  # Like @schema but without `required: true` on :endpoint, so `merge/2` can
  # validate a partial set of overrides against an already-valid config.
  @merge_schema Keyword.update!(@schema, :endpoint, &Keyword.delete(&1, :required))

  @moduledoc """
  Immutable connection and resource context for a TerminusDB server.

  A `Config` carries everything needed to address and authenticate a request:
  the server `:endpoint`, credentials, and the current resource scope
  (`:organization`, `:database`, `:branch`, `:repo`, `:ref`).

  Unlike the official Python client — which holds mutable connection state on an
  instance — `TerminusDB.Config` is **immutable data**. Scoping operations return
  *derived* configs (`with_database/2`, `with_branch/2`, …) rather than mutating,
  which is safe under concurrency and composes naturally with pipelines.

  ## Options

  #{NimbleOptions.docs(@schema)}

  ## Examples

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      iex> config.endpoint
      "http://localhost:6363"
      iex> config.organization
      "admin"

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363", token: "tok_123")
      iex> TerminusDB.Config.auth(config)
      {:bearer, "tok_123"}

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      iex> TerminusDB.Config.auth(config)
      {:basic, "admin:root"}

  """

  @type auth :: {:basic, String.t()} | {:bearer, String.t()} | nil

  @enforce_keys [:endpoint]
  defstruct [
    :endpoint,
    :token,
    :user,
    :key,
    :organization,
    :database,
    :branch,
    :repo,
    :ref,
    :adapter,
    headers: %{},
    receive_timeout: 15_000,
    telemetry: true,
    user_agent: "terminusdb_ex/#{@version}"
  ]

  @type t :: %__MODULE__{
          endpoint: String.t(),
          token: String.t() | nil,
          user: String.t(),
          key: String.t(),
          organization: String.t(),
          database: String.t() | nil,
          branch: String.t(),
          repo: String.t(),
          ref: String.t() | nil,
          adapter: (Req.Request.t() -> {Req.Request.t(), Req.Response.t()}) | nil,
          headers: %{String.t() => String.t()},
          receive_timeout: pos_integer(),
          telemetry: boolean(),
          user_agent: String.t()
        }

  @doc """
  The NimbleOptions schema used to validate `new/1` options.

  ## Examples

      iex> schema = TerminusDB.Config.schema()
      iex> Keyword.has_key?(schema, :endpoint)
      true

  """
  @spec schema() :: keyword()
  def schema, do: @schema

  @doc """
  Builds a new, validated `TerminusDB.Config`.

  ## Options

  See the module documentation or `schema/0` for the accepted options.

  ## Examples

      iex> %TerminusDB.Config{endpoint: "http://localhost:6363"} =
      ...>   TerminusDB.Config.new(endpoint: "http://localhost:6363")

      iex> TerminusDB.Config.new(endpoint: "http://localhost:6363", database: "foo").database
      "foo"

  Raises `NimbleOptions.ValidationError` on invalid options.

      iex> TerminusDB.Config.new(endpoint: 123)
      ** (NimbleOptions.ValidationError) invalid value for :endpoint option: expected string, got: 123

  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    validated = NimbleOptions.validate!(opts, @schema)
    struct!(__MODULE__, validated)
  end

  @doc """
  Returns a copy of `config` with the given fields updated.

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      iex> TerminusDB.Config.merge(config, database: "mydb").database
      "mydb"

  """
  @spec merge(t(), keyword()) :: t()
  def merge(%__MODULE__{} = config, opts) when is_list(opts) do
    validated = NimbleOptions.validate!(opts, @merge_schema)
    struct!(config, validated)
  end

  @doc """
  Scopes `config` to the given organization.

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      iex> TerminusDB.Config.with_organization(config, "acme").organization
      "acme"

  """
  @spec with_organization(t(), String.t()) :: t()
  def with_organization(%__MODULE__{} = config, organization) when is_binary(organization) do
    %{config | organization: organization}
  end

  @doc """
  Scopes `config` to the given database.

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      iex> TerminusDB.Config.with_database(config, "mydb").database
      "mydb"

  """
  @spec with_database(t(), String.t()) :: t()
  def with_database(%__MODULE__{} = config, database) when is_binary(database) do
    %{config | database: database}
  end

  @doc """
  Scopes `config` to the given branch.

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      iex> TerminusDB.Config.with_branch(config, "feature").branch
      "feature"

  """
  @spec with_branch(t(), String.t()) :: t()
  def with_branch(%__MODULE__{} = config, branch) when is_binary(branch) do
    %{config | branch: branch}
  end

  @doc """
  Scopes `config` to the given repository (`local` or a remote name).

  ## Examples

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      iex> TerminusDB.Config.with_repo(config, "origin").repo
      "origin"

  """
  @spec with_repo(t(), String.t()) :: t()
  def with_repo(%__MODULE__{} = config, repo) when is_binary(repo) do
    %{config | repo: repo}
  end

  @doc """
  Pins `config` to a commit reference for time-travel queries.

  ## Examples

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      iex> TerminusDB.Config.with_ref(config, "commit/abc123").ref
      "commit/abc123"

  """
  @spec with_ref(t(), String.t()) :: t()
  def with_ref(%__MODULE__{} = config, ref) when is_binary(ref) do
    %{config | ref: ref}
  end

  @doc """
  Returns the Req auth tuple derived from `config`.

  A `:token` takes precedence (Bearer); otherwise Basic auth is built from
  `:user` and `:key`. Returns `nil` only if no credentials are usable.

  ## Examples

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363", token: "abc")
      iex> TerminusDB.Config.auth(config)
      {:bearer, "abc"}

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363", user: "admin", key: "root")
      iex> TerminusDB.Config.auth(config)
      {:basic, "admin:root"}
  """
  @spec auth(t()) :: auth()
  def auth(%__MODULE__{token: token}) when is_binary(token) and token != "", do: {:bearer, token}

  def auth(%__MODULE__{user: user, key: key}) when is_binary(user) and is_binary(key),
    do: {:basic, "#{user}:#{key}"}

  def auth(%__MODULE__{}), do: nil

  @doc """
  Returns `config` with sensitive fields redacted, suitable for telemetry metadata
  and logging. Replaces `:key` and `:token` with `"[redacted]"`.

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363", key: "secret")
      iex> redacted = TerminusDB.Config.redact(config)
      iex> redacted.key
      "[redacted]"
      iex> redacted.endpoint
      "http://localhost:6363"

  """
  @spec redact(t()) :: t()
  def redact(%__MODULE__{key: key, token: token} = config) do
    %{config | key: redact_value(key), token: redact_value(token)}
  end

  defp redact_value(nil), do: nil
  defp redact_value(_), do: "[redacted]"
end
