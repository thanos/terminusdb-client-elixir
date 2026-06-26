# Path Parse Benchmark
#
# Run: mix run bench/path_parse_bench.exs

alias TerminusDB.WOQL.Path

Benchee.run(
  %{
    "simple pred" => fn -> Path.parse("friend") end,
    "star" => fn -> Path.parse("friend*") end,
    "plus" => fn -> Path.parse("friend+") end,
    "inverse" => fn -> Path.parse("<friend") end,
    "alternation" => fn -> Path.parse("friend|foe") end,
    "sequence" => fn -> Path.parse("friend,foe") end,
    "quantified" => fn -> Path.parse("friend*{1,3}") end,
    "complex" => fn -> Path.parse("(friend,foe)+{2,5}") end,
    "inverse star" => fn -> Path.parse("<friend*") end
  },
  time: 5,
  memory_time: 2
)
