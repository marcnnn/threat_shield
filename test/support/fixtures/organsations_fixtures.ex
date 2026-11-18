defmodule ThreatShield.OrganisationsFixtures do
  @moduledoc """
  This module defines test helpers for creating organisations.
  """

  @doc """
  Generates an organisation with the user as its owner.
  """
  def organisation_fixture(user, attrs \\ %{}) do
    attrs
    |> Enum.into(%{name: "some name"})
    |> ThreatShield.Accounts.create_organisation!(actor: user)
  end
end
