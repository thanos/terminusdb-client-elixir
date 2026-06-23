defmodule TerminusDB.Test.Helpers do
  @moduledoc false

  # Shared helpers for hermetic unit tests using Req's fake adapter.

  alias TerminusDB.Config

  @endpoint "http://localhost:6363"

  @doc """
  Builds a `TerminusDB.Config` with the given fake Req `adapter` and the standard
  test endpoint.
  """
  def config(adapter), do: Config.new(endpoint: @endpoint, adapter: adapter)

  @doc """
  Builds a 200 OK `Req.Response` with the given body (defaults to a success map).
  """
  def ok(body \\ %{"api:status" => "api:success"}), do: Req.Response.new(status: 200, body: body)

  @doc """
  Builds a `Req.Response` with the given status and body.
  """
  def resp(status, body), do: Req.Response.new(status: status, body: body)

  @doc """
  Returns an adapter function that captures the outgoing request by sending it to
  `test_pid`, then returns the given response.
  """
  def capture(test_pid, response) do
    fn req ->
      send(test_pid, {:request, req})
      {req, response}
    end
  end

  @doc """
  Returns an adapter function as-is. Convenience for inline adapters that
  capture the request themselves.
  """
  def capture(adapter_fun) when is_function(adapter_fun, 1), do: adapter_fun

  @doc """
  Retrieves the last request captured by `capture/2`.
  """
  def last_request do
    receive do
      {:request, req} -> req
    after
      0 -> raise "no request was captured"
    end
  end

  @doc """
  Converts a `Req.Request` URL to a string.
  """
  def request_url(%Req.Request{} = req), do: URI.to_string(req.url)
end
