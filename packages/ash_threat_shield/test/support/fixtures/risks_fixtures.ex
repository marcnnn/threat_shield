defmodule AshThreatShield.RisksFixtures do
  @moduledoc """
  This module defines test helpers for creating risks.
  """

  def risk_fixture(user, threat_id, attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      name: "some name",
      description: "some description",
      estimated_cost: 42,
      probability: 120.5,
      threat_id: threat_id
    })
    |> AshThreatShield.ThreatManagement.create_risk!(actor: user)
  end
end
