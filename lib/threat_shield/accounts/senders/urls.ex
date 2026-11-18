defmodule ThreatShield.Accounts.Senders.Urls do
  @moduledoc """
  The links in the account and invite emails point into the web application, which
  this domain does not know. The application configures a module that implements
  this behaviour and builds the links:

      config :threat_shield, :account_urls, ThreatShieldWeb.AccountUrls

  The callback gets the name of the link and the token, and returns the URL:

    * `:confirm` - confirmation of a new account
    * `:reset_password` - password reset
    * `:confirm_email_change` - confirmation of a new email address
    * `:join_organisation` - the invite link of an organisation

  Without the configuration, `build/2` raises: an email without its link is of no
  use, and a missing configuration is a defect of the application.
  """

  @type name :: :confirm | :reset_password | :confirm_email_change | :join_organisation

  @doc """
  Returns the URL of the link `name` for the token.
  """
  @callback url_for(name(), token :: String.t()) :: String.t()

  @doc """
  Builds the URL `name` for the token with the configured module.
  """
  @spec build(name(), String.t()) :: String.t()
  def build(name, token) when is_binary(token), do: module().url_for(name, token)

  defp module do
    case Application.fetch_env(:threat_shield, :account_urls) do
      {:ok, module} when is_atom(module) and not is_nil(module) ->
        module

      _ ->
        raise ArgumentError, """
        no module builds the links of the account emails. Configure one that \
        implements #{inspect(__MODULE__)}:

            config :threat_shield, :account_urls, MyAppWeb.AccountUrls
        """
    end
  end
end
