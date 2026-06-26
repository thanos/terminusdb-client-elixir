# WOQL Encode Benchmark
#
# Run: mix run bench/woql_encode_bench.exs

alias TerminusDB.{WOQL, Benchmark}

Benchee.run(
  %{
    "triple" => fn -> WOQL.to_jsonld(WOQL.triple("v:S", "p", "v:O")) end,
    "and_ (3 ops)" => fn ->
      WOQL.to_jsonld(WOQL.and_([
        WOQL.triple("v:S", "name", "v:Name"),
        WOQL.triple("v:S", "age", "v:Age"),
        WOQL.triple("v:S", "rdf:type", WOQL.iri("@schema:Person"))
      ]))
    end,
    "select + limit" => fn ->
      WOQL.to_jsonld(WOQL.select(["v:Name"], WOQL.limit(10, WOQL.triple("v:P", "name", "v:Name"))))
    end,
    "order_by" => fn ->
      WOQL.to_jsonld(WOQL.order_by([{"v:Age", :asc}], WOQL.and_([
        WOQL.triple("v:P", "name", "v:Name"),
        WOQL.triple("v:P", "age", "v:Age")
      ])))
    end,
    "path (string)" => fn ->
      WOQL.to_jsonld(WOQL.path("v:S", "friend*{1,3}", "v:O"))
    end,
    "interval_relation" => fn ->
      WOQL.to_jsonld(WOQL.interval_relation("v:R", "v:XS", "v:XE", "v:YS", "v:YE"))
    end,
    "triple_slice" => fn ->
      WOQL.to_jsonld(WOQL.triple_slice("v:S", "v:P", "v:O", 10, 100))
    end,
    "get (CSV)" => fn ->
      WOQL.to_jsonld(WOQL.get(WOQL.woql_as([{"name", "v:Name"}]), WOQL.file("data.csv")))
    end
  },
  time: 5,
  memory_time: 2
)
