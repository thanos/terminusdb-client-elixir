defmodule TerminusDB.ErrorTest do
  use ExUnit.Case, async: true

  doctest TerminusDB.Error

  describe "transport/1" do
    test "builds a :transport error from an exception" do
      exception = Req.TransportError.exception(reason: :econnrefused)

      error = TerminusDB.Error.transport(exception)

      assert error.reason == :transport
      assert error.cause == exception
      assert error.status == nil
      assert Exception.message(error) =~ "transport error"
      assert Exception.message(error) =~ "connection refused"
    end
  end

  describe "http/2" do
    test "builds an :http error with status and body" do
      error = TerminusDB.Error.http(503, "service unavailable")

      assert error.reason == :http
      assert error.status == 503
      assert error.body == "service unavailable"
      assert Exception.message(error) == "HTTP error 503"
    end
  end

  describe "api/2" do
    test "parses a structured TerminusDB error body" do
      body = %{
        "@type" => "api:DbCreateErrorResponse",
        "api:error" => %{"@type" => "api:DatabaseAlreadyExists", "api:database_name" => "mydb"},
        "api:message" => "Database already exists.",
        "api:status" => "api:failure"
      }

      error = TerminusDB.Error.api(400, body)

      assert error.reason == :api
      assert error.status == 400
      assert error.api_type == "api:DatabaseAlreadyExists"
      assert error.api_error == body["api:error"]
      assert error.body == body

      assert Exception.message(error) ==
               "TerminusDB API error 400 (api:DatabaseAlreadyExists): Database already exists."
    end

    test "falls back to top-level @type when api:error is absent" do
      error = TerminusDB.Error.api(404, %{"@type" => "api:NotFound", "api:message" => "missing"})

      assert error.api_type == "api:NotFound"
      assert Exception.message(error) == "TerminusDB API error 404 (api:NotFound): missing"
    end

    test "uses a default message when api:message is missing" do
      error = TerminusDB.Error.api(500, %{"@type" => "api:ServerError"})

      assert Exception.message(error) ==
               "TerminusDB API error 500 (api:ServerError): API error 500"
    end

    test "falls back to top-level @type when api:error map has no @type" do
      error =
        TerminusDB.Error.api(400, %{
          "@type" => "api:TopLevel",
          "api:error" => %{"api:database_name" => "mydb"}
        })

      assert error.api_type == "api:TopLevel"
    end
  end

  describe "decode/2" do
    test "builds a :decode error" do
      exception = Jason.DecodeError.exception(data: "{bad", position: 1)

      error = TerminusDB.Error.decode(exception, "{bad")

      assert error.reason == :decode
      assert error.cause == exception
      assert error.body == "{bad"
      assert Exception.message(error) =~ "decode error"
    end
  end

  describe "exception/1 + raise" do
    test "can be raised and rescued" do
      error =
        TerminusDB.Error.exception(
          reason: :api,
          status: 400,
          api_type: "api:DatabaseAlreadyExists",
          message: "boom"
        )

      assert_raise TerminusDB.Error, "boom", fn -> raise error end
    end

    test "derives a default message for :api without api_type" do
      error = TerminusDB.Error.exception(reason: :api, status: 400)
      assert Exception.message(error) == "TerminusDB API error"
    end

    test "derives a default message for :api with api_type" do
      error = TerminusDB.Error.exception(reason: :api, status: 400, api_type: "api:SomeError")
      assert Exception.message(error) == "TerminusDB API error (api:SomeError)"
    end

    test "derives a default message for :http" do
      error = TerminusDB.Error.exception(reason: :http, status: 503)
      assert Exception.message(error) == "HTTP error 503"
    end

    test "derives a default message for :transport" do
      error = TerminusDB.Error.exception(reason: :transport)
      assert Exception.message(error) == "transport error"
    end

    test "derives a default message for :decode" do
      error = TerminusDB.Error.exception(reason: :decode)
      assert Exception.message(error) == "decode error"
    end

    test "derives a default message for an unknown reason" do
      error = TerminusDB.Error.exception(reason: :unknown)
      assert Exception.message(error) == "unknown error"
    end
  end

  describe "message/1 fallback clause" do
    test "returns the stored message for reasons not matched by earlier clauses" do
      # An :http error with nil status doesn't match the :http clause guard
      # (which requires `status` to be bound), so the fallback clause is used.
      error = %TerminusDB.Error{reason: :http, status: nil, message: "custom message"}
      assert Exception.message(error) == "custom message"
    end
  end
end
