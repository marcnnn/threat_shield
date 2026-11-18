defmodule ThreatShield.Accounts.Changes.SendInviteEmail do
  @moduledoc """
  Sends the link of a new invite to the invited address, once the invite is stored.
  The link is built by the configured module of `ThreatShield.Accounts.Senders.Urls`.
  """
  use Ash.Resource.Change

  require Logger

  alias ThreatShield.Accounts.Senders.Urls
  alias ThreatShield.Accounts.UserNotifier

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, invite} ->
        deliver(invite, Ash.Context.to_opts(context))
        {:ok, invite}

      _changeset, error ->
        error
    end)
  end

  # The invite is stored; a failed delivery is logged, and the invite can be revoked
  # and sent again.
  defp deliver(invite, opts) do
    with {:ok, invite} <- Ash.load(invite, [:organisation_name], opts),
         {:ok, _email} <-
           UserNotifier.deliver_invite(invite, Urls.build(:join_organisation, invite.token)) do
      :ok
    else
      {:error, error} ->
        Logger.error("The invite #{invite.id} was not sent: #{inspect(error)}")
    end
  end
end
