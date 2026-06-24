defmodule TerminusDB.Error do
  @moduledoc """
  A structured error returned by all `terminusdb_ex` operations.

  Public API functions return `{:error, %TerminusDB.Error{}}` on failure; the
  `!/1`-suffixed variants raise this same struct (it implements the `Exception`
  behaviour). The `:reason` field classifies the failure so callers can pattern match
  without inspecting HTTP status:

  | `:reason`   | Meaning                                                |
  | ----------- | ----------------------------------------------------- |
  | `:transport`| Network/transport failure (connection, timeout, …)    |
  | `:http`     | Non-2xx response with a non-JSON or unstructured body |
  | `:api`      | TerminusDB API error (structured `api:*` JSON body)  |
  | `:decode`   | Response body could not be decoded as JSON           |

  ## Examples

      iex> error = TerminusDB.Error.api(400, %{
      ...>   "@type" => "api:DbCreateErrorResponse",
      ...>   "api:error" => %{"@type" => "api:DatabaseAlreadyExists"},
      ...>   "api:message" => "Database already exists.",
      ...>   "api:status" => "api:failure"
      ...> })
      iex> error.reason
      :api
      iex> error.api_type
      "api:DatabaseAlreadyExists"
      iex> Exception.message(error)
      "TerminusDB API error 400 (api:DatabaseAlreadyExists): Database already exists."

  """

  @type reason :: :transport | :http | :api | :decode

  @type t :: %__MODULE__{
          reason: reason(),
          status: pos_integer() | nil,
          message: String.t(),
          api_error: map() | nil,
          api_type: String.t() | nil,
          body: term(),
          cause: Exception.t() | nil
        }

  @enforce_keys [:reason]
  defexception [:reason, :status, :message, :api_error, :api_type, :body, :cause]

  # Public constructors -------------------------------------------------------

  @doc """
  Builds a `:transport` error from an underlying exception (e.g. `Req.TransportError`).

  ## Examples

      iex> error = TerminusDB.Error.transport(Req.TransportError.exception(reason: :econnrefused))
      iex> error.reason
      :transport

  """
  @spec transport(Exception.t()) :: t()
  def transport(%{__exception__: true} = exception) do
    %__MODULE__{
      reason: :transport,
      message: "transport error: #{Exception.message(exception)}",
      cause: exception
    }
  end

  @doc """
  Builds an `:http` error from a non-2xx status with an unstructured body.

  ## Examples

      iex> error = TerminusDB.Error.http(503, "service unavailable")
      iex> error.reason
      :http

  """
  @spec http(pos_integer(), term()) :: t()
  def http(status, body) when is_integer(status) do
    %__MODULE__{reason: :http, status: status, body: body, message: "HTTP error #{status}"}
  end

  @doc """
  Builds an `:api` error from a TerminusDB structured error body.

  TerminusDB returns JSON of the shape
  `{"@type": "api:*ErrorResponse", "api:error": {...}, "api:message": "...", "api:status": "api:failure"}`.
  The `@type` inside `api:error` (if present) is surfaced as `api_type` for easy
  pattern matching, e.g. `"api:DatabaseAlreadyExists"`.
  """
  @spec api(pos_integer(), map()) :: t()
  def api(status, %{} = body) when is_integer(status) do
    api_error = body["api:error"]
    api_type = (is_map(api_error) && api_error["@type"]) || body["@type"]
    message = body["api:message"] || "API error #{status}"

    %__MODULE__{
      reason: :api,
      status: status,
      api_error: api_error,
      api_type: api_type,
      body: body,
      message: "TerminusDB API error #{status}#{format_api_type(api_type)}: #{message}"
    }
  end

  @doc """
  Builds a `:decode` error when the response body cannot be parsed as JSON.
  """
  @spec decode(Exception.t(), binary() | nil) :: t()
  def decode(%{__exception__: true} = exception, body) do
    %__MODULE__{
      reason: :decode,
      message: "decode error: #{Exception.message(exception)}",
      cause: exception,
      body: body
    }
  end

  # Exception callback --------------------------------------------------------

  @impl true
  def exception(opts) when is_list(opts) do
    reason = Keyword.fetch!(opts, :reason)

    %__MODULE__{
      reason: reason,
      status: opts[:status],
      message: opts[:message] || default_message(reason, opts),
      api_error: opts[:api_error],
      api_type: opts[:api_type],
      body: opts[:body],
      cause: opts[:cause]
    }
  end

  @impl true
  @spec message(t()) :: String.t()
  def message(%__MODULE__{reason: :api} = error), do: error.message

  def message(%__MODULE__{reason: :transport, cause: cause} = _e) when cause != nil,
    do: "transport error: #{Exception.message(cause)}"

  def message(%__MODULE__{reason: :decode, cause: cause} = _e) when cause != nil,
    do: "decode error: #{Exception.message(cause)}"

  def message(%__MODULE__{reason: :http, status: status} = _e) when status != nil,
    do: "HTTP error #{status}"

  def message(%__MODULE__{message: message}), do: message

  defp default_message(:api, opts), do: "TerminusDB API error#{format_api_type(opts[:api_type])}"
  defp default_message(:http, opts), do: "HTTP error #{opts[:status]}"
  defp default_message(:transport, _opts), do: "transport error"
  defp default_message(:decode, _opts), do: "decode error"
  defp default_message(_, _opts), do: "unknown error"

  defp format_api_type(nil), do: ""
  defp format_api_type(type), do: " (#{type})"
end
