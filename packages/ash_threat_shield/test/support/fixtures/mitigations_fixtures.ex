defmodule AshThreatShield.MitigationsFixtures do
  @moduledoc """
  This module defines test helpers for creating mitigations.
  """

  def mitigation_fixture(user, risk, attrs \\ %{}) do
    attrs
    |> Enum.into(%{name: "some name", description: "some description", risk_id: risk.id})
    |> AshThreatShield.ThreatManagement.create_mitigation!(actor: user)
  end
end
