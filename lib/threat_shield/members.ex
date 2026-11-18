defmodule ThreatShield.Members do
  @moduledoc """
  The Members context - delegates to Ash resources.
  """

  require Ash.Query
  require Logger

  alias ThreatShield.Access
  alias ThreatShield.Accounts.{Organisation, Membership, User}
  alias ThreatShield.Accounts.Invite

  def get_organisation!(%User{} = user, org_id) do
    Access.get!(Organisation, user, org_id, nil, [:invites, memberships: :user])
  end

  def get_invite_by_token(token) do
    case Ash.read(Invite,
           action: :get_by_token,
           args: %{token: token},
           authorize?: false,
           load: [:organisation]
         ) do
      {:ok, invite} -> invite
      _ -> nil
    end
  end

  # Invites are matched by email address, so the address must be confirmed first.
  def get_invites_by_user(%User{confirmed_at: nil}), do: []

  def get_invites_by_user(%User{email: email}) do
    Invite
    |> Ash.Query.for_read(:for_user_email, %{email: email}, authorize?: false)
    |> Ash.Query.load([:organisation])
    |> Ash.read!(authorize?: false)
  end

  def join_with_token(%User{} = user, token) do
    with %Invite{} = invite <- get_invite_by_token(token),
         {:ok, :no_member} <- check_membership(user, invite.organisation_id) do
      convert_to_membership(user, invite)
    else
      {:ok, :is_member} -> {:error, :already_member}
      nil -> {:error, :invalid_token}
    end
  end

  @doc """
  Invites an email address to an organisation. The actor needs the right to invite
  members. An address can be invited only once per organisation.
  """
  def create_invite(%User{} = actor, %Organisation{id: org_id}, attrs \\ %{}) do
    organisation = Access.get!(Organisation, actor, org_id, :invite_new_members)

    Invite
    |> Ash.Changeset.for_create(
      :create,
      ThreatShield.Params.put(attrs, :organisation_id, organisation.id),
      authorize?: false,
      skip_unknown_inputs: :*
    )
    |> Ash.create(load: [:organisation])
  end

  def delete_membership_by_id(%User{} = actor, org_id, membership_id) do
    membership =
      case Access.get(Membership, actor, membership_id, :delete_member,
             organisation: :memberships
           ) do
        {:ok, membership} -> membership
        {:error, :not_found} -> nil
      end

    with %Membership{organisation: %Organisation{} = org} <- membership,
         true <- to_string(org.id) == to_string(org_id),
         :ok <- assert_not_last_member(org, membership),
         :ok <- assert_not_last_owner(org, membership) do
      Logger.warning(
        "User #{actor.id} is deleting membership #{membership.id} from organisation #{org.id}"
      )

      Ash.destroy!(membership, authorize?: false)
      {:ok, membership}
    else
      {:error, :last_owner} -> {:error, :last_owner}
      {:error, :last_member} -> {:error, :last_member}
      _ -> {:error, :not_allowed}
    end
  end

  def accept_invite(%User{confirmed_at: nil}, _invite_id), do: {:error, :email_not_confirmed}

  def accept_invite(%User{} = invitee, invite_id) do
    # the address is compared by the database, without regard to case
    invite =
      invitee
      |> invites_of_user_query()
      |> Ash.Query.filter(id == ^invite_id)
      |> Ash.Query.load([:organisation])
      |> Ash.read_one(authorize?: false)

    with {:ok, %Invite{} = invite} <- invite,
         {:ok, :no_member} <- check_membership(invitee, invite.organisation_id) do
      convert_to_membership(invitee, invite)
    else
      {:ok, :is_member} -> {:error, :already_member}
      _ -> {:error, :invalid_invite}
    end
  end

  @doc """
  Deletes an invite that was sent to the given user.
  """
  def reject_invite(%User{confirmed_at: nil}, _invite_id), do: {:error, :not_found}

  def reject_invite(%User{} = invitee, invite_id) do
    invitee
    |> invites_of_user_query()
    |> Ash.Query.filter(id == ^invite_id)
    |> Ash.read_one(authorize?: false)
    |> delete_invite()
  end

  @doc """
  Deletes an invite of an organisation. The actor needs the right to invite members.
  """
  def revoke_invite(%User{} = actor, invite_id) do
    Invite
    |> Access.get(actor, invite_id, :invite_new_members)
    |> delete_invite()
  end

  defp delete_invite({:ok, %Invite{} = invite}) do
    Ash.destroy!(invite, authorize?: false)
    {:ok, invite}
  end

  defp delete_invite(_), do: {:error, :not_found}

  def delete_expired_invites do
    invites = Ash.read!(Invite, action: :expired, authorize?: false)
    Enum.each(invites, &Ash.destroy!(&1, authorize?: false))
    {length(invites), invites}
  end

  def change_invite(%Invite{} = invite, attrs \\ %{}) do
    invite
    |> Ecto.Changeset.cast(attrs, [:email])
    |> Ecto.Changeset.validate_required([:email])
    |> Ecto.Changeset.validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> Ecto.Changeset.validate_length(:email, max: 160)
  end

  def change_membership(%Membership{} = membership, attrs \\ %{}) do
    membership
    |> Ecto.Changeset.cast(attrs, [:role])
    |> Ecto.Changeset.validate_required([:role])
  end

  def update_role(%User{} = user, %Membership{id: membership_id}, role) do
    membership =
      Access.get!(Membership, user, membership_id, :edit_membership, organisation: :memberships)

    num_owners =
      Enum.count(membership.organisation.memberships, fn m -> m.role == :owner end)

    if membership.role == :owner and num_owners <= 1 do
      {:error, :last_owner}
    else
      membership
      |> Ash.Changeset.for_update(:update_role, %{role: role}, authorize?: false)
      |> Ash.update()
    end
  end

  # internal

  # The invites to the email address of the user that have not expired.
  defp invites_of_user_query(%User{email: email}) do
    Ash.Query.for_read(Invite, :for_user_email, %{email: email}, authorize?: false)
  end

  defp convert_to_membership(%User{} = user, %Invite{} = invite) do
    Ash.transaction([Membership, Invite], fn ->
      membership =
        Membership
        |> Ash.Changeset.for_create(
          :create,
          %{user_id: user.id, organisation_id: invite.organisation_id, role: :viewer},
          authorize?: false
        )
        |> Ash.create!()
        |> Ash.load!(:organisation, authorize?: false)

      Ash.destroy!(invite, authorize?: false)
      membership
    end)
  end

  defp check_membership(%User{id: user_id}, org_id) do
    member? =
      Membership
      |> Ash.Query.filter(user_id == ^user_id and organisation_id == ^org_id)
      |> Ash.exists?(authorize?: false)

    if member?, do: {:ok, :is_member}, else: {:ok, :no_member}
  end

  defp assert_not_last_member(%Organisation{memberships: memberships}, _membership) do
    if length(memberships) > 1 do
      :ok
    else
      {:error, :last_member}
    end
  end

  defp assert_not_last_owner(%Organisation{memberships: memberships}, %Membership{role: :owner}) do
    owner_count = Enum.count(memberships, fn m -> m.role == :owner end)

    if owner_count <= 1 do
      {:error, :last_owner}
    else
      :ok
    end
  end

  defp assert_not_last_owner(_organisation, %Membership{role: _}), do: :ok
end
