defmodule AshThreatShield.Test.Fixtures do
  @moduledoc """
  Users, organisations and memberships of the test host.
  """

  alias AshThreatShield.Test.Accounts

  def user_fixture do
    Accounts.create_user!(%{email: "user#{System.unique_integer()}@example.com"})
  end

  @doc """
  Creates an organisation with the user as its owner.
  """
  def organisation_fixture(user, attrs \\ %{}) do
    attrs
    |> Enum.into(%{name: "some name"})
    |> Accounts.create_organisation!(actor: user)
  end

  @doc """
  Adds the user to the organisation with the given role.
  """
  def membership_fixture(organisation, user, role) do
    Accounts.create_membership!(%{
      organisation_id: organisation.id,
      user_id: user.id,
      role: role
    })
  end
end
