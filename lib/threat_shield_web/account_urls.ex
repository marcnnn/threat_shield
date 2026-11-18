defmodule ThreatShieldWeb.AccountUrls do
  @moduledoc """
  The links of the account and invite emails, see
  `ThreatShield.Accounts.Senders.Urls`.
  """
  @behaviour ThreatShield.Accounts.Senders.Urls

  use ThreatShieldWeb, :verified_routes

  @impl true
  def url_for(:confirm, token), do: url(~p"/users/confirm/#{token}")
  def url_for(:reset_password, token), do: url(~p"/users/reset_password/#{token}")
  def url_for(:confirm_email_change, token), do: url(~p"/users/settings/confirm_email/#{token}")
  def url_for(:join_organisation, token), do: url(~p"/join/#{token}")
end
