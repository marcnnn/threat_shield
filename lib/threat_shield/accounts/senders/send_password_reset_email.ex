defmodule ThreatShield.Accounts.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends the password reset instructions.
  """
  use AshAuthentication.Sender

  alias ThreatShield.Accounts.Senders.Urls
  alias ThreatShield.Accounts.UserNotifier

  @impl true
  def send(user, token, _opts) do
    UserNotifier.deliver_reset_password_instructions(user, Urls.build(:reset_password, token))
  end
end
