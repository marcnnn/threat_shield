defmodule ThreatShield.SystemsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ThreatShield.Systems` context.
  """

  def system_fixture(user, organisation, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        attributes: %{},
        name: "some name",
        description: "some description"
      })

    {:ok, system} = ThreatShield.Systems.create_system(user, organisation, attrs)

    system
  end
end
