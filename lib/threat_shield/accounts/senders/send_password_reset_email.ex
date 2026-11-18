defmodule ThreatShield.Accounts.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email via AshAuthentication.
  """
  use AshAuthentication.Sender

  alias ThreatShield.Accounts.UserNotifier

  @impl true
  def send(user, token, _opts) do
    url = ThreatShieldWeb.Endpoint.url() <> "/auth/user/password/reset?token=#{token}"
    UserNotifier.deliver_reset_password_instructions(user, url)
  end
end
