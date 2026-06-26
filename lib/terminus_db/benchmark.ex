defmodule TerminusDB.Benchmark do
  @moduledoc """
  Benchmarking helpers for `terminusdb_ex`.

  Provides utilities for generating test data, seeding databases, and
  creating representative WOQL queries for benchmarking.

  ## Quick start

      # Generate test data
      people = TerminusDB.Benchmark.generate_data(1000)

      # Seed a database
      config = TerminusDB.Benchmark.seed_database(config, 500)

      # Get representative queries
      queries = TerminusDB.Benchmark.generate_queries(100)

  """

  alias TerminusDB.{Config, Database, Document, WOQL}

  @doc """
  Generates `count` Person documents with random names and ages.
  """
  @spec generate_data(pos_integer()) :: [map()]
  def generate_data(count) do
    Enum.map(1..count, fn i ->
      %{
        "@type" => "Person",
        "name" => "Person_#{i}",
        "age" => :rand.uniform(100)
      }
    end)
  end

  @doc """
  Creates a database with a Person schema and inserts `count` documents.
  """
  @spec seed_database(Config.t(), pos_integer()) :: Config.t()
  def seed_database(config, count) do
    db_name = "bench_#{:erlang.unique_integer([:positive])}"
    Database.create!(config, db_name, label: "Benchmark", schema: true)
    scoped = Config.with_database(config, db_name)

    Document.insert!(
      scoped,
      %{
        "@type" => "Class",
        "@id" => "Person",
        "@key" => %{"@type" => "Lexical", "@fields" => ["name"]},
        "name" => "xsd:string",
        "age" => "xsd:integer"
      },
      author: "admin",
      message: "add schema",
      graph_type: :schema
    )

    data = generate_data(count)

    Document.insert!(
      scoped,
      data,
      author: "admin",
      message: "seed #{count} documents"
    )

    scoped
  end

  @doc """
  Returns a list of representative WOQL queries for benchmarking.
  """
  @spec generate_queries(pos_integer()) :: [WOQL.t()]
  def generate_queries(count) do
    [
      # Simple triple pattern
      WOQL.triple("v:Person", "name", "v:Name"),

      # And with multiple patterns
      WOQL.and_([
        WOQL.triple("v:Person", "name", "v:Name"),
        WOQL.triple("v:Person", "age", "v:Age"),
        WOQL.triple("v:Person", "rdf:type", WOQL.iri("@schema:Person"))
      ]),

      # Select with limit
      WOQL.select(["v:Name"], WOQL.limit(count, WOQL.triple("v:P", "name", "v:Name"))),

      # Order by
      WOQL.select(
        ["v:Name", "v:Age"],
        WOQL.order_by(
          [{"v:Age", :asc}],
          WOQL.and_([
            WOQL.triple("v:P", "name", "v:Name"),
            WOQL.triple("v:P", "age", "v:Age")
          ])
        )
      ),

      # Path query
      WOQL.path("v:S", "friend+", "v:O"),

      # Arithmetic
      WOQL.eval(WOQL.plus(["v:Age", 1]), "v:Result"),

      # String concat
      WOQL.concat(["v:Name", "_suffix"], "v:Result")
    ]
  end

  @doc """
  Returns path patterns of varying complexity for benchmarking.
  """
  @spec generate_path_patterns() :: [String.t()]
  def generate_path_patterns do
    [
      "friend",
      "friend*",
      "friend+",
      "<friend",
      "friend|foe",
      "friend,foe",
      "friend*{1,3}",
      "friend+{2,5}",
      "(friend,foe)+",
      "<friend*"
    ]
  end
end
