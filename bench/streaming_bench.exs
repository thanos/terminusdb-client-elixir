# Streaming vs Batch Benchmark
#
# Run: mix run bench/streaming_bench.exs
# Requires: docker compose up -d

alias TerminusDB.{Benchmark, Config, Document}

endpoint = System.get_env("TERMINUSDB_URL", "http://localhost:6363")

config =
  Config.new(endpoint: endpoint, user: "admin", key: "root")
  |> Config.with_database("bench_stream_#{:erlang.unique_integer([:positive])}")

# Seed with 500 documents
seeded = Benchmark.seed_database(config, 500)

Benchee.run(
  %{
    "get all (as_list)" => fn ->
      Document.get(seeded, type: "Person", as_list: true)
    end,
    "stream (collect)" => fn ->
      seeded
      |> Document.stream(type: "Person")
      |> Enum.to_list()
    end
  },
  time: 10,
  memory_time: 2
)

# Cleanup
TerminusDB.Database.delete(config, config.database, force: true)
