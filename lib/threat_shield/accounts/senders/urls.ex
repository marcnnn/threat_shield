defmodule ThreatShield.Accounts.Senders.Urls do
  @moduledoc """
  The links in the account emails point into the web application, which this domain
  does not know. The caller of an action that sends such an email passes URL
  builders in the action context:

      Accounts.request_password_reset(email,
        context: Urls.context(%{reset_password: &url(~p"/users/reset_password/\#{&1}")})
      )

  A builder takes the token and returns the URL. The senders use these keys:

    * `:confirm` - confirmation of a new account
    * `:reset_password` - password reset
    * `:confirm_email_change` - confirmation of a new email address

  Without a builder, the email is not sent.
  """

  require Logger

  @key :account_urls

  @doc """
  Returns the action context that carries the given URL builders.
  """
  def context(builders) when is_map(builders), do: %{@key => builders}

  @doc """
  Builds the URL `name` for the token from the URL builders in the action context
  that a sender receives in its options.
  """
  def build(opts, name, token) do
    case get_in(action_context(opts), [@key, name]) do
      builder when is_function(builder, 1) ->
        {:ok, builder.(token)}

      _ ->
        Logger.warning("No URL builder #{inspect(name)} in the action context, email not sent")
        :error
    end
  end

  defp action_context(opts) do
    case opts[:context] || opts[:changeset] do
      %{context: context} -> context
      context when is_map(context) -> context
      _ -> %{}
    end
  end
end
