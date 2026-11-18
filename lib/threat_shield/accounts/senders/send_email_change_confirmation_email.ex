defmodule ThreatShield.Accounts.Senders.SendEmailChangeConfirmationEmail do
  @moduledoc """
  Sends the confirmation instructions for a new email address to that address.
  """
  use AshAuthentication.Sender

  alias ThreatShield.Accounts.Senders.Urls
  alias ThreatShield.Accounts.UserNotifier

  @impl true
  def send(user, token, opts) do
    new_email = Ash.Changeset.get_attribute(Keyword.fetch!(opts, :changeset), :email)

    url = Urls.build(:confirm_email_change, token)
    UserNotifier.deliver_update_email_instructions(user, new_email, url)
  end
end
