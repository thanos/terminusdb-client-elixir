defmodule TerminusDB.Telemetry do
  @moduledoc """
  Telemetry event definitions and emission helpers for `terminusdb_ex`.

  Every public operation emits a `[:start]` and `[:stop]` event of the form:

      [:terminusdb, <area>, :start]
      [:terminusdb, <area>, :stop]

  where `<area>` is one of `:database`, `:document`, `:query`, `:branch`,
  `:merge`, `:diff`, or `:connection`.

  ## Measurements

  - `start`: `%{system_time: System.monotonic_time()}`
  - `stop`:  `%{duration: native_time, system_time: System.monotonic_time()}`

  `duration` is in `:native` time units; convert in handlers with
  `System.convert_time_unit(duration, :native, :millisecond)`.

  ## Metadata

  Both events carry `%{config: redacted_config, method: atom, path: String.t(), area: atom}`
  plus, on `:stop`, `status: pos_integer | nil` and `error: TerminusDB.Error.t() | nil`.
  The caller (typically `TerminusDB.Client`) is responsible for redacting the config via
  `TerminusDB.Config.redact/1` before placing it in the meta, so credentials never leak.

  ## Attaching

      :telemetry.attach_many(
        "my-handler",
        [[:terminusdb, :database, :stop], [:terminusdb, :query, :stop]],
        fn event, measurements, meta, _ctx ->
          # log slow queries, push metrics, ...
        end,
        nil
      )

  """

  @type area ::
          :database
          | :document
          | :query
          | :branch
          | :merge
          | :diff
          | :commit
          | :woql
          | :connection

  @doc """
  Returns the event name for a given `area` and `stage` (`:start` or `:stop`).

      iex> TerminusDB.Telemetry.event_name(:database, :start)
      [:terminusdb, :database, :start]

  """
  @spec event_name(area(), :start | :stop) :: [atom(), ...]
  def event_name(area, stage) when stage in [:start, :stop] do
    [:terminusdb, area, stage]
  end

  @doc """
  Emits the `[:start]` event for `area` with the given metadata.

  Returns the monotonic time captured for the measurement, so callers can pass it to
  `stop/4`. No-op when `config.telemetry` is `false`.

  ## Examples

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      iex> meta = %{path: "db/admin/mydb", method: :post}
      iex> start_time = TerminusDB.Telemetry.start(:database, meta, config)
      iex> is_integer(start_time)
      true

  """
  @spec start(area(), map(), TerminusDB.Config.t()) :: integer() | nil
  def start(area, meta, %TerminusDB.Config{telemetry: true}) do
    system_time = System.monotonic_time()
    :telemetry.execute(event_name(area, :start), %{system_time: system_time}, meta)
    system_time
  end

  def start(_area, _meta, %TerminusDB.Config{telemetry: false}), do: nil

  @doc """
  Emits the `[:stop]` event for `area`, computing `duration` from `start_monotonic`.

  Accepts an optional `status` (HTTP status code) and `error` (`TerminusDB.Error.t()`)
  to include in the metadata. No-op when `config.telemetry` is `false`.

  ## Examples

      iex> config = TerminusDB.Config.new(endpoint: "http://localhost:6363")
      iex> meta = %{path: "db/admin/mydb", method: :post, config: TerminusDB.Config.redact(config)}
      iex> start_time = TerminusDB.Telemetry.start(:database, meta, config)
      iex> :ok = TerminusDB.Telemetry.stop(:database, meta, start_time, config, status: 200, error: nil)
      iex> :ok
      :ok

  """
  @spec stop(area(), map(), integer() | nil, TerminusDB.Config.t(), keyword()) :: :ok | nil
  def stop(area, meta, start_monotonic, %TerminusDB.Config{telemetry: true}, opts) do
    stop_time = System.monotonic_time()
    duration = start_monotonic && stop_time - start_monotonic

    measurements = %{duration: duration, system_time: stop_time}

    # Config is already redacted by the caller (Client) in meta[:config].
    # Reuse it rather than re-redacting.
    stop_meta =
      meta
      |> Map.put(:status, opts[:status])
      |> Map.put(:error, opts[:error])

    :telemetry.execute(event_name(area, :stop), measurements, stop_meta)
    :ok
  end

  def stop(_area, _meta, _start, %TerminusDB.Config{telemetry: false}, _opts), do: nil
end
