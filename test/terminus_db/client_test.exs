defmodule TerminusDB.ClientTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Client, Config, Error}
  import TerminusDB.Test.Helpers

  doctest TerminusDB.Client

  # Tests ---------------------------------------------------------------------

  describe "request/4 — successful responses" do
    test "returns the decoded body for 2xx" do
      adapter = fn req -> {req, ok(%{"api:status" => "api:success"})} end

      assert {:ok, %{"api:status" => "api:success"}} =
               Client.request(config(adapter), :get, "ok")
    end

    test "sends the configured base URL, method, path, auth, and user-agent" do
      test = self()

      adapter =
        capture(fn req ->
          send(test, {:request, req})
          {req, ok(%{})}
        end)

      Client.request(config(adapter), :get, "ok")

      req = last_request()
      assert req.method == :get
      assert request_url(req) == "http://localhost:6363/api/ok"

      assert Req.Request.get_header(req, "user-agent") == [
               "terminusdb_ex/#{Mix.Project.config()[:version]}"
             ]

      assert Req.Request.get_header(req, "authorization") == ["Basic YWRtaW46cm9vdA=="]
    end

    test "encodes the :json body and posts it" do
      test = self()

      adapter = fn req ->
        send(test, {:request, req})
        {req, ok(%{"api:status" => "api:success"})}
      end

      Client.request(config(adapter), :post, "db/admin/mydb",
        json: %{"label" => "My DB", "schema" => true},
        area: :database
      )

      req = last_request()
      assert req.method == :post
      assert request_url(req) == "http://localhost:6363/api/db/admin/mydb"
      assert {:ok, body} = Jason.decode(req.body)
      assert body == %{"label" => "My DB", "schema" => true}
      assert Req.Request.get_header(req, "content-type") == ["application/json"]
    end

    test "appends :params to the query string" do
      test = self()

      adapter = fn req ->
        send(test, {:request, req})
        {req, ok(%{})}
      end

      Client.request(config(adapter), :get, "db/admin/mydb",
        params: [branches: true, verbose: false]
      )

      req = last_request()
      uri = req.url
      assert uri.path == "/api/db/admin/mydb"
      assert uri.query == "branches=true&verbose=false"
    end

    test "uses bearer auth when a token is configured" do
      test = self()

      adapter = fn req ->
        send(test, {:request, req})
        {req, ok(%{})}
      end

      cfg = Config.new(endpoint: "http://localhost:6363", token: "tok_123", adapter: adapter)
      Client.request(cfg, :get, "ok")

      req = last_request()
      assert Req.Request.get_header(req, "authorization") == ["Bearer tok_123"]
    end
  end

  describe "request/4 — error mapping" do
    test "maps a structured 4xx body to an :api error" do
      body = %{
        "@type" => "api:DbCreateErrorResponse",
        "api:error" => %{"@type" => "api:DatabaseAlreadyExists"},
        "api:message" => "Database already exists.",
        "api:status" => "api:failure"
      }

      adapter = fn req -> {req, resp(400, body)} end

      assert {:error, %Error{reason: :api, status: 400, api_type: "api:DatabaseAlreadyExists"}} =
               Client.request(config(adapter), :post, "db/admin/mydb", json: %{})
    end

    test "maps a JSON binary error body to an :api error" do
      body = Jason.encode!(%{"@type" => "api:NotFound", "api:message" => "missing"})

      adapter = fn req ->
        {req,
         Req.Response.new(
           status: 404,
           headers: %{"content-type" => ["application/json"]},
           body: body
         )}
      end

      assert {:error, %Error{reason: :api, status: 404, api_type: "api:NotFound"}} =
               Client.request(config(adapter), :get, "db/admin/missing")
    end

    test "decodes a JSON binary body without content-type header in build_status_error" do
      # When the response has no content-type: application/json header, Req's
      # decode_body step leaves the binary body as-is. build_status_error must
      # then Jason.decode it itself and produce an :api error.
      body = Jason.encode!(%{"@type" => "api:BadRequest", "api:message" => "nope"})

      adapter = fn req ->
        {req, Req.Response.new(status: 400, body: body)}
      end

      assert {:error, %Error{reason: :api, status: 400, api_type: "api:BadRequest"}} =
               Client.request(config(adapter), :get, "db/admin/bad")
    end

    test "maps a non-JSON error body to an :http error" do
      adapter = fn req ->
        {req, Req.Response.new(status: 502, body: "Bad Gateway")}
      end

      assert {:error, %Error{reason: :http, status: 502, body: "Bad Gateway"}} =
               Client.request(config(adapter), :get, "ok")
    end

    test "maps an adapter exception to a :transport error" do
      adapter = fn req -> {req, Req.TransportError.exception(reason: :econnrefused)} end

      assert {:error, %Error{reason: :transport, cause: %Req.TransportError{}}} =
               Client.request(config(adapter), :get, "ok")
    end

    test "maps an empty-map error body to an :api error with nil api_type" do
      adapter = fn req -> {req, resp(400, %{})} end

      assert {:error, %Error{reason: :api, status: 400, api_type: nil}} =
               Client.request(config(adapter), :get, "db/admin/bad")
    end
  end

  describe "request!/4" do
    test "returns the body on success" do
      adapter = fn req -> {req, ok(%{"api:status" => "api:success"})} end
      assert Client.request!(config(adapter), :get, "ok") == %{"api:status" => "api:success"}
    end

    test "raises TerminusDB.Error on failure" do
      adapter = fn req -> {req, resp(503, "down")} end

      assert_raise TerminusDB.Error, "HTTP error 503", fn ->
        Client.request!(config(adapter), :get, "ok")
      end
    end
  end

  describe "request_response/4" do
    test "returns the full Req.Response" do
      adapter = fn req -> {req, Req.Response.new(status: 201, body: "created")} end

      assert {:ok, %Req.Response{status: 201, body: "created"}} =
               Client.request_response(config(adapter), :post, "db/admin/mydb", json: %{})
    end

    test ":raw returns the full response even on 2xx" do
      adapter = fn req -> {req, ok(%{"x" => 1})} end

      assert {:ok, %Req.Response{body: %{"x" => 1}}} =
               Client.request(config(adapter), :get, "ok", raw: true)
    end
  end

  describe "resource_path/2" do
    test "joins org and db from config" do
      config = Config.with_database(Config.new(endpoint: "http://localhost:6363"), "mydb")
      assert Client.resource_path(config, []) == "admin/mydb"
    end

    test "honors :organization override" do
      config = Config.with_database(Config.new(endpoint: "http://localhost:6363"), "mydb")
      assert Client.resource_path(config, organization: "acme") == "acme/mydb"
    end

    test "raises when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363")
      assert_raise TerminusDB.Error, fn -> Client.resource_path(config, []) end
    end
  end

  describe "telemetry" do
    setup do
      events = [
        TerminusDB.Telemetry.event_name(:database, :start),
        TerminusDB.Telemetry.event_name(:database, :stop)
      ]

      test = self()
      ref = make_ref()

      :telemetry.attach_many(
        "client-test-#{inspect(ref)}",
        events,
        fn event, measurements, meta, _ctx -> send(test, {:event, event, measurements, meta}) end,
        nil
      )

      on_exit(fn -> :telemetry.detach("client-test-#{inspect(ref)}") end)
      :ok
    end

    test "emits start/stop for the given area with status and redacted config" do
      adapter = fn req -> {req, ok(%{})} end

      # A unique path isolates this test's events from other concurrent tests
      # that also emit [:terminusdb, :database, *] events (telemetry is global).
      Client.request(config(adapter), :post, "telemetry/ok-a",
        json: %{},
        area: :database
      )

      assert_receive {:event, [:terminusdb, :database, :start], start_meas,
                      %{path: "telemetry/ok-a"} = start_meta}

      assert start_meta.method == :post
      assert start_meta.area == :database
      assert is_integer(start_meas[:system_time])

      assert_receive {:event, [:terminusdb, :database, :stop], stop_meas,
                      %{path: "telemetry/ok-a"} = stop_meta}

      assert stop_meta.status == 200
      assert stop_meta.error == nil
      assert is_integer(stop_meas[:duration])
      assert stop_meta.config.key == "[redacted]"
    end

    test "emits stop with the error on failure" do
      adapter = fn req -> {req, resp(500, "boom")} end

      Client.request(config(adapter), :get, "telemetry/err-b", area: :database)

      assert_receive {:event, [:terminusdb, :database, :stop], _,
                      %{path: "telemetry/err-b"} = stop_meta}

      assert stop_meta.status == 500
      assert %Error{reason: :http} = stop_meta.error
    end

    test "emits stop with status nil and a :transport error on adapter exception" do
      adapter = fn req -> {req, Req.TransportError.exception(reason: :econnrefused)} end

      Client.request(config(adapter), :get, "telemetry/err-c", area: :database)

      assert_receive {:event, [:terminusdb, :database, :stop], _,
                      %{path: "telemetry/err-c"} = stop_meta}

      assert stop_meta.status == nil
      assert %Error{reason: :transport} = stop_meta.error
    end
  end
end
