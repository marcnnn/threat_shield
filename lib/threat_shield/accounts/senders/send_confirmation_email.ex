defmodule ThreatShield.Accounts.Senders.SendConfirmationEmail do
  @moduledoc """
  Sends the confirmation instructions for a new account.
  """
  use AshAuthentication.Sender

  alias ThreatShield.Accounts.Senders.Urls
  alias ThreatShield.Accounts.UserNotifier

  @impl true
  def send(user, token, _opts) do
    UserNotifier.deliver_confirmation_instructions(user, Urls.build(:confirm, token))
  end
end
