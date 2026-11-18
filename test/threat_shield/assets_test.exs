defmodule ThreatShield.AssetsTest do
  use ThreatShield.DataCase

  alias ThreatShield.AccountsFixtures
  alias ThreatShield.AssetsFixtures
  alias ThreatShield.OrganisationsFixtures
  alias ThreatShield.SystemsFixtures
  alias ThreatShield.ThreatsFixtures
  alias ThreatShield.ThreatManagement
  alias ThreatShield.ThreatManagement.{Asset, Threat}

  setup do
    user = AccountsFixtures.user_fixture()
    organisation = OrganisationsFixtures.organisation_fixture(user)
    %{user: user, organisation: organisation}
  end

  test "create_asset with valid data creates an asset", %{user: user, organisation: organisation} do
    assert {:ok, %Asset{}} =
             ThreatManagement.create_asset(
               %{
                 name: "some_name",
                 description: "some description",
                 organisation_id: organisation.id
               },
               actor: user
             )
  end

  test "the overall criticality is at least the average of the other criticalities",
       %{user: user, organisation: organisation} do
    asset =
      AssetsFixtures.asset_fixture(user, organisation, %{
        criticality_loss: 3.0,
        criticality_theft: 4.0,
        criticality_publication: 5.0,
        criticality_overall: 1.0
      })

    assert asset.criticality_overall == 4.0

    {:ok, asset} =
      ThreatManagement.update_asset(asset, %{criticality_overall: 5.0, criticality_loss: 0.0},
        actor: user
      )

    assert asset.criticality_overall == 5.0

    {:ok, asset} = ThreatManagement.update_asset(asset, %{criticality_overall: 0.0}, actor: user)
    assert asset.criticality_overall == 3.0
    assert Repo.get!(Asset, asset.id).criticality_overall == 3.0
  end

  test "list_assets_of_system returns the assets of the system only",
       %{user: user, organisation: organisation} do
    system = SystemsFixtures.system_fixture(user, organisation)
    asset = AssetsFixtures.asset_fixture(user, organisation, %{system_id: system.id})
    AssetsFixtures.asset_fixture(user, organisation)

    assert [%Asset{id: id}] = ThreatManagement.list_assets_of_system!(system.id, actor: user)
    assert id == asset.id
  end

  test "destroy_asset keeps the threats of the asset and clears the reference",
       %{user: user, organisation: organisation} do
    asset = AssetsFixtures.asset_fixture(user, organisation)
    threat = ThreatsFixtures.threat_fixture(user, organisation, %{asset_id: asset.id})

    assert :ok = ThreatManagement.destroy_asset(asset.id, actor: user)

    refute Repo.get(Asset, asset.id)
    assert %Threat{asset_id: nil} = Repo.get(Threat, threat.id)
  end
end
