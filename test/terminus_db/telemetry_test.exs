defmodule TerminusDB.TelemetryTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Telemetry}

  doctest TerminusDB.Telemetry

  @config Config.new(endpoint: "http://localhost:6363")
  @disabled Config.new(endpoint: "http://localhost:6363", telemetry: false)

  describe "event_name/2" do
    test "builds [:terminusdb, area, stage]" do
      assert Telemetry.event_name(:database, :start) == [:terminusdb, :database, :start]
      assert Telemetry.event_name(:query, :stop) == [:terminusdb, :query, :stop]
    end
  end

  describe "start/3 and stop/5" do
    setup do
      events = [Telemetry.event_name(:database, :start), Telemetry.event_name(:database, :stop)]
      test = self()
      ref = make_ref()

      :telemetry.attach_many(
        "test-handler-#{inspect(ref)}",
        events,
        fn event, measurements, meta, _ctx -> send(test, {:event, event, measurements, meta}) end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-handler-#{inspect(ref)}") end)
      :ok
    end

    test "emits start and stop with measurements and metadata" do
      # A unique path isolates this test's events from other concurrent tests
      # that emit [:terminusdb, :database, *] events (telemetry is global).
      # The caller (Client) is responsible for putting the redacted config in meta.
      meta = %{path: "telemetry/direct", method: :post, config: Config.redact(@config)}

      start_time = Telemetry.start(:database, meta, @config)
      assert is_integer(start_time)

      assert_receive {:event, [:terminusdb, :database, :start], measurements,
                      %{path: "telemetry/direct"} = received_meta}

      assert is_integer(measurements[:system_time])
      assert received_meta.method == :post

      :ok = Telemetry.stop(:database, meta, start_time, @config, status: 200, error: nil)

      assert_receive {:event, [:terminusdb, :database, :stop], stop_measurements,
                      %{path: "telemetry/direct"} = stop_meta}

      assert is_integer(stop_measurements[:duration])
      assert stop_measurements[:system_time] >= start_time
      assert stop_meta.status == 200
      assert stop_meta.error == nil
      # config is carried through from the start meta (already redacted by caller)
      assert stop_meta.config.key == "[redacted]"
    end

    test "is a no-op when telemetry is disabled" do
      # Use a unique path so the unfiltered refute_receive does not catch
      # :database events leaked from other concurrent tests (telemetry is
      # global). We never emit on this path (telemetry disabled), so we should
      # receive nothing tagged with it.
      unique = "telemetry/noop-#{:erlang.unique_integer([:positive])}"
      meta = %{path: unique, method: :post}

      assert Telemetry.start(:database, meta, @disabled) == nil
      assert Telemetry.stop(:database, meta, nil, @disabled, status: 200) == nil

      refute_receive {:event, _, _, %{path: ^unique}}, 10
    end
  end
end
