# WOQL Decode Benchmark
#
# Run: mix run bench/woql_decode_bench.exs

alias TerminusDB.WOQL

# Pre-encode queries for decoding
triple_jsonld = WOQL.to_jsonld(WOQL.triple("v:S", "p", "v:O"))

and_jsonld = WOQL.to_jsonld(WOQL.and_([
  WOQL.triple("v:S", "name", "v:Name"),
  WOQL.triple("v:S", "age", "v:Age"),
  WOQL.triple("v:S", "rdf:type", WOQL.iri("@schema:Person"))
]))

select_jsonld = WOQL.to_jsonld(WOQL.select(["v:Name"], WOQL.limit(10, WOQL.triple("v:P", "name", "v:Name"))))

path_jsonld = WOQL.to_jsonld(WOQL.path("v:S", "friend*{1,3}", "v:O"))

interval_jsonld = WOQL.to_jsonld(WOQL.interval_relation("v:R", "v:XS", "v:XE", "v:YS", "v:YE"))

Benchee.run(
  %{
    "triple" => fn -> WOQL.from_jsonld(triple_jsonld) end,
    "and_ (3 ops)" => fn -> WOQL.from_jsonld(and_jsonld) end,
    "select + limit" => fn -> WOQL.from_jsonld(select_jsonld) end,
    "path" => fn -> WOQL.from_jsonld(path_jsonld) end,
    "interval_relation" => fn -> WOQL.from_jsonld(interval_jsonld) end
  },
  time: 5,
  memory_time: 2
)
