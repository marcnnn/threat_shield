defmodule ThreatShield.Accounts.Token do
  @moduledoc """
  The tokens of AshAuthentication: sessions, API sign ins, confirmations, password
  resets and revocations. Only AshAuthentication works with them.
  """

  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "user_tokens"
    repo ThreatShield.Repo
  end

  actions do
    defaults [:read, :destroy]
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end
end
