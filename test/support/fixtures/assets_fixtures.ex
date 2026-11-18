defmodule ThreatShield.AssetsFixtures do
  @moduledoc """
  This module defines test helpers for creating assets.
  """

  def asset_fixture(user, organisation, attrs \\ %{}) do
    %{name: "some name", description: "some description", organisation_id: organisation.id}
    |> Map.merge(attrs)
    |> ThreatShield.ThreatManagement.create_asset!(actor: user)
  end
end
