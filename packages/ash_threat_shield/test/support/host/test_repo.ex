defmodule AshThreatShield.TestRepo do
  @moduledoc """
  The repo of the test host. Its migrations are generated with `mix ash.codegen`
  into `priv/test_repo/migrations`.
  """
  use AshPostgres.Repo, otp_app: :ash_threat_shield

  @impl true
  def installed_extensions, do: ["ash-functions"]

  @impl true
  def min_pg_version, do: %Version{major: 16, minor: 0, patch: 0}
end
