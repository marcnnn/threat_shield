defmodule ThreatShield.SystemsFixtures do
  @moduledoc """
  This module defines test helpers for creating systems.
  """

  def system_fixture(user, organisation, attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      attributes: %{},
      name: "some name",
      description: "some description",
      organisation_id: organisation.id
    })
    |> ThreatShield.ThreatManagement.create_system!(actor: user)
  end
end
