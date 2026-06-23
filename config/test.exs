import Config

# Quiet logger noise during test runs.
config :logger, level: :warning

# ExCoveralls
config :terminusdb_client, :excoveralls, threshold: 80
