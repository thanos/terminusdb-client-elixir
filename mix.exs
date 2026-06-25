defmodule TerminusDB.MixProject do
  use Mix.Project

  @version "0.3.1-dev"
  @source_url "https://github.com/thanos/terminusdb-client-elixir"
  @description """
  An idiomatic Elixir client for TerminusDB, the version-controlled document graph
  database. Features DB management, document CRUD with streaming, schema frames,
  branching, commit history, diff/merge, a WOQL query DSL, a Req-based HTTP client,
  immutable configs, typed errors, and telemetry.
  """

  def project do
    [
      app: :terminusdb_client,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      package: package(),
      docs: docs(),
      name: "terminusdb_ex",
      source_url: @source_url,
      description: @description
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TerminusDB.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        "coveralls.detail": :test,
        credo: :dev,
        dialyzer: :dev,
        sobelow: :dev,
        docs: :dev
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.2"},

      # Dev / test only
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:sobelow, "~> 0.13", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false},
      {:stream_data, "~> 1.1", only: [:test, :dev]}
    ]
  end

  defp dialyzer do
    [
      list_unused_filters: true,
      plt_add_apps: [:req, :jason, :telemetry, :nimble_options],
      plt_core_path: "_build/plts",
      plt_file: {:no_warn, "_build/plts/terminusdb_client.plt"}
    ]
  end

  defp package do
    [
      name: "terminusdb_client",
      licenses: ["Apache-2.0"],
      maintainers: ["Thanos Vassilakis"],
      links: %{
        "GitHub" => @source_url,
        "TerminusDB docs" => "https://terminusdb.org/docs/"
      },
      keywords: [
        "terminusdb",
        "graph-database",
        "document-database",
        "woql",
        "datalog",
        "rdf",
        "json-ld",
        "knowledge-graph",
        "ecto",
        "version-control"
      ],
      exclude_patterns: ["_build", "test", "docs/adr", "baoulo"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        {"README.md", [title: "Overview"]},
        {"guides/introduction.md", [title: "Introduction to TerminusDB"]},
        {"guides/migrating-from-sql.md", [title: "Migrating from SQL"]},
        {"guides/overview.md", [title: "Overview Guide"]},
        {"CHANGELOG.md", [title: "Changelog"]},
        {"ARCHITECTURE.md", [title: "Architecture"]},
        {"LICENSE", [title: "License"]}
      ],
      groups_for_extras: [
        Guides: ["guides/introduction.md", "guides/migrating-from-sql.md", "guides/overview.md"],
        Architecture: ["ARCHITECTURE.md"]
      ],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp aliases do
    [
      quality: ["format --check-formatted", "credo --strict", "sobelow --exit Low", "dialyzer"],
      verify: &verify/1
    ]
  end

  defp verify(_) do
    steps = [
      {"compile --warnings-as-errors", :dev},
      {"format --check-formatted", :dev},
      {"credo --strict", :dev},
      {"sobelow --exit Low", :dev},
      {"dialyzer", :dev},
      {"test --cover", :test},
      {"docs --warnings-as-errors", :dev}
    ]

    Enum.each(steps, fn {task, env} ->
      Mix.shell().info(IO.ANSI.format([:bright, "==> mix #{task}", :reset]))

      mix_executable =
        System.find_executable("mix") ||
          Mix.raise("Could not find `mix` executable on PATH")

      {_, exit_code} =
        System.cmd(mix_executable, String.split(task),
          env: [{"MIX_ENV", to_string(env)}],
          into: IO.stream(:stdio, :line),
          stderr_to_stdout: true
        )

      if exit_code != 0 do
        Mix.raise("mix #{task} failed (exit code #{exit_code})")
      end
    end)

    Mix.shell().info(
      IO.ANSI.format([:green, :bright, "\nAll verification checks passed!", :reset])
    )
  end
end
