defmodule ThreatShield.Accounts.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends the password reset instructions.
  """
  use AshAuthentication.Sender

  alias ThreatShield.Accounts.Senders.Urls
  alias ThreatShield.Accounts.UserNotifier

  @impl true
  def send(user, token, opts) do
    with {:ok, url} <- Urls.build(opts, :reset_password, token) do
      UserNotifier.deliver_reset_password_instructions(user, url)
    end
  end
end
