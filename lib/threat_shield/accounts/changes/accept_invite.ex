defmodule ThreatShield.Accounts.Changes.AcceptInvite do
  @moduledoc """
  Turns an invite into a membership of the actor with the role `:viewer`, and deletes
  the invite in the same transaction.

  With `by: :id`, the invite is given by the argument `invite_id` and must be
  addressed to the confirmed email address of the actor. With `by: :token`, the
  invite is given by the argument `token`, the secret of the invite link.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias ThreatShield.Accounts.Errors.InviteError
  alias ThreatShield.Accounts.{Invite, Membership}

  @impl true
  def change(changeset, opts, %{actor: %{id: _} = actor}) do
    # The invite is read in the transaction and locked, so that it is used up once
    # even if two requests accept it at the same time.
    Ash.Changeset.before_action(changeset, fn changeset ->
      with {:ok, invite} <- fetch_invite(changeset, opts[:by], actor),
           :ok <- not_a_member(actor, invite.organisation_id) do
        accept(changeset, invite, actor)
      else
        {:error, reason} ->
          Ash.Changeset.add_error(changeset, InviteError.exception(reason: reason))
      end
    end)
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset, InviteError.exception(reason: :invalid_invite))
  end

  defp accept(changeset, invite, actor) do
    changeset
    |> Ash.Changeset.force_change_attributes(%{
      user_id: actor.id,
      organisation_id: invite.organisation_id,
      role: :viewer
    })
    |> Ash.Changeset.after_action(fn _changeset, membership ->
      # The invite is used up. The policy of this action has authorized the
      # invitee, who may not destroy invites otherwise.
      case Ash.destroy(invite, authorize?: false) do
        :ok -> {:ok, membership}
        {:error, error} -> {:error, error}
      end
    end)
  end

  defp fetch_invite(_changeset, :id, %{confirmed_at: nil}), do: {:error, :email_not_confirmed}

  defp fetch_invite(changeset, :id, actor) do
    invite_id = Ash.Changeset.get_argument(changeset, :invite_id)

    Invite
    |> Ash.Query.for_read(:received, %{}, actor: actor)
    |> Ash.Query.filter(id == ^invite_id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one()
    |> case do
      {:ok, %Invite{} = invite} -> {:ok, invite}
      _ -> {:error, :invalid_invite}
    end
  end

  defp fetch_invite(changeset, :token, actor) do
    token = Ash.Changeset.get_argument(changeset, :token)

    Invite
    |> Ash.Query.for_read(:by_token, %{token: token}, actor: actor)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one()
    |> case do
      {:ok, %Invite{} = invite} -> {:ok, invite}
      _ -> {:error, :invalid_token}
    end
  end

  defp not_a_member(actor, organisation_id) do
    Membership
    |> Ash.Query.filter(user_id == ^actor.id and organisation_id == ^organisation_id)
    |> Ash.exists?(actor: actor)
    |> if(do: {:error, :already_member}, else: :ok)
  end
end
