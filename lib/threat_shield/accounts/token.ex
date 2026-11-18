defmodule ThreatShield.Accounts.Token do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "user_tokens"
    repo ThreatShield.Repo
  end

  actions do
    defaults [:read, :destroy]
  end
end
