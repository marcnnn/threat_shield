defmodule ThreatShield.Accounts.Senders.SendConfirmationEmail do
  @moduledoc """
  Sends a confirmation email via AshAuthentication.
  """
  use AshAuthentication.Sender

  alias ThreatShield.Accounts.UserNotifier

  @impl true
  def send(user, token, _opts) do
    url = ThreatShieldWeb.Endpoint.url() <> "/auth/user/confirm_new_user?confirm=#{token}"
    UserNotifier.deliver_confirmation_instructions(user, url)
  end
end
