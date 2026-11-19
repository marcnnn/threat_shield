defmodule AshThreatShield.ThreatsFixtures do
  @moduledoc """
  This module defines test helpers for creating threats.
  """

  def threat_fixture(user, organisation, attrs \\ %{}) do
    %{name: "some name", description: "some description", organisation_id: organisation.id}
    |> Map.merge(attrs)
    |> AshThreatShield.ThreatManagement.create_threat!(actor: user)
  end
end
