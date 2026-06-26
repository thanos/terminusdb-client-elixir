# Document CRUD Benchmark
#
# Run: mix run bench/document_crud_bench.exs
# Requires: docker compose up -d

alias TerminusDB.{Benchmark, Config, Document}

endpoint = System.get_env("TERMINUSDB_URL", "http://localhost:6363")

config =
  Config.new(endpoint: endpoint, user: "admin", key: "root")
  |> Config.with_database("bench_crud_#{:erlang.unique_integer([:positive])}")

# Seed
{seeded, db_name} = Benchmark.seed_database(config, 100)

Benchee.run(
  %{
    "insert 1 doc" => fn ->
      Document.insert(seeded, %{"@type" => "Person", "name" => "Bench_#{:erlang.unique_integer([:positive])}", "age" => 25},
        author: "admin", message: "bench insert"
      )
    end,
    "get by id" => fn ->
      Document.get(seeded, id: "Person/Person_1")
    end,
    "get by type" => fn ->
      Document.get(seeded, type: "Person", as_list: true, count: 10)
    end
  },
  time: 10,
  memory_time: 2
)

# Cleanup
TerminusDB.Database.delete(config, db_name, force: true)
