import Config

config :ash_threat_shield, AshThreatShield.TestRepo, pool: Ecto.Adapters.SQL.Sandbox

# Ignore missed Ash notifications in tests (sandbox transactions)
config :ash, :missed_notifications, :ignore

config :logger, level: :warning
