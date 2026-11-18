defmodule ThreatShield.MembersTest do
  use ThreatShield.DataCase

  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.{Invite, Membership, Organisation}
  alias ThreatShield.Accounts.Errors.InviteError
  alias ThreatShield.AccountsFixtures
  alias ThreatShield.MembersFixtures
  alias ThreatShield.OrganisationsFixtures

  defp invite_error_reason({:error, error}), do: InviteError.reason(error)

  describe "members" do
    test "an existing user accepts an invite and becomes a viewer" do
      owner = AccountsFixtures.user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(owner)
      other_user = AccountsFixtures.confirmed_user_fixture()

      invite = MembersFixtures.invite_fixture(owner, organisation, to_string(other_user.email))
      assert %Invite{} = invite

      assert {:ok, %Membership{role: :viewer} = membership} =
               Accounts.accept_invite(invite.id, actor: other_user)

      assert membership.organisation_id == organisation.id
      refute Repo.get(Invite, invite.id)

      assert [%Organisation{id: org_id}] = Accounts.list_organisations!(actor: other_user)
      assert org_id == organisation.id
    end

    test "a user cannot be added twice to an organisation" do
      owner = AccountsFixtures.user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(owner)
      other_user = AccountsFixtures.confirmed_user_fixture()
      email = to_string(other_user.email)

      invite_1 = MembersFixtures.invite_fixture(owner, organisation, email)
      {:ok, %Membership{}} = Accounts.accept_invite(invite_1.id, actor: other_user)

      invite_2 = MembersFixtures.invite_fixture(owner, organisation, email)

      assert :already_member =
               invite_error_reason(Accounts.accept_invite(invite_2.id, actor: other_user))
    end

    test "the creator of an organisation becomes its owner" do
      user = AccountsFixtures.user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(user)

      assert [%Membership{role: :owner, user_id: user_id}] =
               Repo.all(from m in Membership, where: m.organisation_id == ^organisation.id)

      assert user_id == user.id
    end
  end

  describe "invites" do
    setup do
      owner = AccountsFixtures.user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(owner)
      invite = MembersFixtures.invite_fixture(owner, organisation, "invited@example.com")

      %{owner: owner, organisation: organisation, invite: invite}
    end

    test "an account with an unconfirmed email address does not see the invite and cannot accept it",
         %{invite: invite} do
      user = AccountsFixtures.user_fixture(%{email: "invited@example.com"})

      assert Accounts.list_received_invites!(actor: user) == []

      assert :email_not_confirmed =
               invite_error_reason(Accounts.accept_invite(invite.id, actor: user))

      assert Accounts.list_organisations!(actor: user) == []
    end

    test "an account with a confirmed email address sees the invite", %{invite: invite} do
      user = AccountsFixtures.confirmed_user_fixture(%{email: "invited@example.com"})

      assert [%Invite{id: invite_id} = received] =
               Accounts.list_received_invites!(actor: user, load: [:organisation_name])

      assert invite_id == invite.id
      assert received.organisation_name == "some name"
    end

    test "the email address is matched without regard to case", %{invite: invite} do
      user = AccountsFixtures.confirmed_user_fixture(%{email: "Invited@Example.com"})

      assert [%Invite{id: invite_id}] = Accounts.list_received_invites!(actor: user)
      assert invite_id == invite.id
      assert {:ok, %Membership{}} = Accounts.accept_invite(invite.id, actor: user)
    end

    test "an invite sends the link to join to the invited address",
         %{owner: owner, organisation: organisation} do
      {:ok, invite} =
        Accounts.create_invite(organisation.id, %{email: "new@example.com"}, actor: owner)

      assert_received {:email, %{to: [{_, "new@example.com"}], text_body: body}}
      assert body =~ ThreatShieldWeb.AccountUrls.url_for(:join_organisation, invite.token)
      assert body =~ organisation.name

      assert {:error, _} =
               Accounts.create_invite(organisation.id, %{email: "new@example.com"}, actor: owner)

      refute_received {:email, %{to: [{_, "new@example.com"}]}}
    end

    test "an address can be invited only once per organisation",
         %{owner: owner, organisation: organisation} do
      assert {:error, %Ash.Error.Invalid{} = error} =
               Accounts.create_invite(organisation.id, %{"email" => "INVITED@example.com"},
                 actor: owner
               )

      assert "has already been invited to this organisation" in errors_on(error).email

      other_organisation = OrganisationsFixtures.organisation_fixture(owner)

      assert {:ok, %Invite{}} =
               Accounts.create_invite(other_organisation.id, %{"email" => "invited@example.com"},
                 actor: owner
               )
    end

    test "an invite for another email address cannot be accepted", %{invite: invite} do
      other_user = AccountsFixtures.confirmed_user_fixture()

      assert :invalid_invite =
               invite_error_reason(Accounts.accept_invite(invite.id, actor: other_user))

      assert Accounts.list_organisations!(actor: other_user) == []
    end

    test "an expired invite cannot be accepted and is deleted by the cleanup", %{invite: invite} do
      user = AccountsFixtures.confirmed_user_fixture(%{email: "invited@example.com"})
      long_ago = DateTime.add(DateTime.utc_now(), -30, :day)
      Repo.update_all(from(i in Invite, where: i.id == ^invite.id), set: [inserted_at: long_ago])

      assert Accounts.list_received_invites!(actor: user) == []
      assert :invalid_invite = invite_error_reason(Accounts.accept_invite(invite.id, actor: user))
      assert {:ok, nil} = Accounts.get_invite_by_token(invite.token)

      Accounts.delete_expired_invites()
      refute Repo.get(Invite, invite.id)
    end

    test "anybody with the token of the link can join", %{
      organisation: organisation,
      invite: invite
    } do
      assert {:ok, %Invite{id: invite_id}} = Accounts.get_invite_by_token(invite.token)
      assert invite_id == invite.id

      user = AccountsFixtures.user_fixture()

      assert {:ok, %Membership{role: :viewer} = membership} =
               Accounts.join_with_token(invite.token, actor: user)

      assert membership.organisation_id == organisation.id
      assert :invalid_token = invite_error_reason(Accounts.join_with_token("wrong", actor: user))
    end

    test "only the invitee can reject an invite", %{invite: invite} do
      invitee = AccountsFixtures.confirmed_user_fixture(%{email: "invited@example.com"})
      other_user = AccountsFixtures.confirmed_user_fixture()

      assert {:error, _} = Accounts.reject_invite(invite.id, actor: other_user)
      assert Repo.get(Invite, invite.id)

      assert :ok = Accounts.reject_invite(invite.id, actor: invitee)
      refute Repo.get(Invite, invite.id)
    end

    test "only an owner of the organisation can revoke and list invites",
         %{owner: owner, organisation: organisation, invite: invite} do
      viewer = AccountsFixtures.user_fixture()
      MembersFixtures.membership_fixture(organisation, viewer, :viewer)
      editor = AccountsFixtures.user_fixture()
      MembersFixtures.membership_fixture(organisation, editor, :editor)

      other_owner = AccountsFixtures.user_fixture()
      OrganisationsFixtures.organisation_fixture(other_owner)

      for user <- [viewer, editor, other_owner] do
        assert {:error, _} = Accounts.revoke_invite(invite.id, actor: user)
        assert Ash.read!(Invite, actor: user) == []
      end

      assert Repo.get(Invite, invite.id)

      assert [%Invite{}] = Ash.read!(Invite, actor: owner)
      assert :ok = Accounts.revoke_invite(invite.id, actor: owner)
      refute Repo.get(Invite, invite.id)
    end

    test "only an owner can invite", %{organisation: organisation} do
      editor = AccountsFixtures.user_fixture()
      MembersFixtures.membership_fixture(organisation, editor, :editor)
      outsider = AccountsFixtures.user_fixture()

      for user <- [editor, outsider] do
        assert {:error, %Ash.Error.Forbidden{}} =
                 Accounts.create_invite(organisation.id, %{email: "x@example.com"}, actor: user)
      end
    end
  end

  describe "memberships" do
    setup do
      owner = AccountsFixtures.user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(owner)
      member = AccountsFixtures.user_fixture()
      membership = MembersFixtures.membership_fixture(organisation, member, :viewer)

      %{owner: owner, organisation: organisation, member: member, membership: membership}
    end

    test "an owner can remove a member", %{owner: owner, membership: membership} do
      assert :ok = Accounts.destroy_membership(membership, actor: owner)
      refute Repo.get(Membership, membership.id)
    end

    test "a viewer and an editor cannot remove a member or change a role",
         %{organisation: organisation, member: member, membership: membership} do
      editor = AccountsFixtures.user_fixture()
      MembersFixtures.membership_fixture(organisation, editor, :editor)

      for user <- [member, editor] do
        assert {:error, _} = Accounts.destroy_membership(membership, actor: user)

        assert {:error, %Ash.Error.Forbidden{}} =
                 Accounts.update_membership_role(membership, :owner, actor: user)
      end

      assert %Membership{role: :viewer} = Repo.get(Membership, membership.id)
    end

    test "members read the users of their organisation, others do not",
         %{owner: owner, organisation: organisation, member: member} do
      organisation =
        Accounts.get_organisation!(organisation.id, actor: member, load: [memberships: :user])

      assert organisation.memberships |> Enum.map(& &1.user.id) |> Enum.sort() ==
               Enum.sort([owner.id, member.id])

      assert Accounts.get_user!(owner.id, actor: member).id == owner.id

      stranger = AccountsFixtures.user_fixture()
      OrganisationsFixtures.organisation_fixture(stranger)

      assert {:error, %Ash.Error.Invalid{}} = Accounts.get_user(owner.id, actor: stranger)
      assert {:error, %Ash.Error.Invalid{}} = Accounts.get_user(stranger.id, actor: member)
    end

    test "an owner of another organisation cannot see, remove or change a member",
         %{membership: membership} do
      other_owner = AccountsFixtures.user_fixture()
      OrganisationsFixtures.organisation_fixture(other_owner)

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.get_membership(membership.id, actor: other_owner)

      assert {:error, _} = Accounts.destroy_membership(membership, actor: other_owner)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.update_membership_role(membership, :owner, actor: other_owner)

      assert %Membership{role: :viewer} = Repo.get(Membership, membership.id)
    end

    test "a membership cannot be created directly", %{organisation: organisation, owner: owner} do
      user = AccountsFixtures.user_fixture()

      assert {:error, %Ash.Error.Forbidden{}} =
               Membership
               |> Ash.Changeset.for_create(
                 :create,
                 %{organisation_id: organisation.id, user_id: user.id, role: :owner},
                 actor: owner
               )
               |> Ash.create()
    end

    test "an owner can change a role", %{owner: owner, membership: membership} do
      assert {:ok, %Membership{role: :editor}} =
               Accounts.update_membership_role(membership, :editor, actor: owner)
    end

    test "the last owner cannot be removed or lose the role",
         %{owner: owner, organisation: organisation} do
      owner_membership =
        Repo.get_by!(Membership, user_id: owner.id, organisation_id: organisation.id)

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.destroy_membership(owner_membership, actor: owner)

      assert {:error, %Ash.Error.Invalid{} = error} =
               Accounts.update_membership_role(owner_membership, :viewer, actor: owner)

      assert %{role: ["the last owner must stay an owner"]} = errors_on(error)
      assert %Membership{role: :owner} = Repo.get(Membership, owner_membership.id)
    end

    test "one of two owners can lose the role, then the other one cannot",
         %{owner: owner, organisation: organisation, member: member, membership: membership} do
      {:ok, second} = Accounts.update_membership_role(membership, :owner, actor: owner)

      owner_membership =
        Repo.get_by!(Membership, user_id: owner.id, organisation_id: organisation.id)

      assert {:ok, _} = Accounts.update_membership_role(owner_membership, :editor, actor: owner)

      assert {:error, error} = Accounts.update_membership_role(second, :viewer, actor: member)
      assert %{role: ["the last owner must stay an owner"]} = errors_on(error)
    end

    test "the organisation counts its members and owners and has the membership of the actor",
         %{owner: owner, organisation: organisation, member: member} do
      owner_id = owner.id

      assert %{
               member_count: 2,
               owner_count: 1,
               actor_membership: %Membership{user_id: ^owner_id, role: :owner}
             } =
               Accounts.get_organisation!(organisation.id,
                 actor: owner,
                 load: [:member_count, :owner_count, :actor_membership]
               )

      assert %{actor_membership: %Membership{role: :viewer}} =
               Accounts.get_organisation!(organisation.id,
                 actor: member,
                 load: [:actor_membership]
               )
    end
  end
end
