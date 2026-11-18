defmodule ThreatShield.MembersFixtures do
  @moduledoc """
  This module defines test helpers for memberships and invites.
  """

  @doc """
  Invites an email address to the organisation, as the given owner.
  """
  def invite_fixture(owner, organisation, email) do
    ThreatShield.Accounts.create_invite!(organisation.id, %{email: email}, actor: owner)
  end

  @doc """
  Adds the user to the organisation with the given role.
  """
  def membership_fixture(organisation, user, role) do
    ThreatShield.Accounts.Membership
    |> Ash.Changeset.for_create(
      :create,
      %{organisation_id: organisation.id, user_id: user.id, role: role},
      authorize?: false
    )
    |> Ash.create!()
  end
end
