defmodule ThreatShield.Accounts.User.TokenSigningSecret do
  @moduledoc """
  The secret that signs the tokens of AshAuthentication, from
  `config :threat_shield, :token_signing_secret`.
  """
  use AshAuthentication.Secret

  @impl true
  def secret_for(
        [:authentication, :tokens, :signing_secret],
        ThreatShield.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:threat_shield, :token_signing_secret)
  end
end
