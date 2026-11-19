# The configuration of the library when it is developed and tested on its own, with
# the test host in test/support/host. A host application configures the library in
# its own config files (see the README); these files are not used then.
import Config

config :ash_threat_shield,
  ecto_repos: [AshThreatShield.TestRepo],
  ash_domains: [AshThreatShield.ThreatManagement, AshThreatShield.Test.Accounts],
  repo: AshThreatShield.TestRepo,
  owner_resource: AshThreatShield.Test.Organisation,
  authorization: AshThreatShield.Test.Authorization,
  ai_provider: AshThreatShield.AI.Providers.Stub,
  ai_hook: AshThreatShield.Test.AiHook

config :ash_threat_shield, AshThreatShield.TestRepo,
  username: System.get_env("POSTGRES_USER", "threat_shield"),
  password: System.get_env("POSTGRES_PASSWORD", "secret"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "ash_threat_shield_#{config_env()}#{System.get_env("MIX_TEST_PARTITION")}",
  priv: "priv/test_repo",
  pool_size: 10

# the Ash settings of the host application in this repository
config :ash,
  include_embedded_source_by_default?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false]

import_config "#{config_env()}.exs"
