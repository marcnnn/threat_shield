defmodule AshThreatShield.SystemsTest do
  use AshThreatShield.DataCase

  alias AshThreatShield.AssetsFixtures
  alias AshThreatShield.RisksFixtures
  alias AshThreatShield.SystemsFixtures
  alias AshThreatShield.ThreatManagement
  alias AshThreatShield.ThreatManagement.{Asset, Risk, System, Threat}
  alias AshThreatShield.ThreatsFixtures

  describe "systems" do
    test "create_system with valid data creates a system" do
      user = user_fixture()
      organisation = organisation_fixture(user)

      assert {:ok, %System{} = system} =
               ThreatManagement.create_system(
                 %{
                   name: "some name",
                   description: "some description",
                   organisation_id: organisation.id
                 },
                 actor: user
               )

      assert system.attributes == %{}
      assert Repo.get!(System, system.id).attributes == %{}
      assert ThreatManagement.Description.system(system) =~ "some name"
    end

    test "destroy_system deletes the assets and threats of the system" do
      user = user_fixture()
      organisation = organisation_fixture(user)
      system = SystemsFixtures.system_fixture(user, organisation, %{name: "a system"})
      asset = AssetsFixtures.asset_fixture(user, organisation, %{system_id: system.id})

      threat =
        ThreatsFixtures.threat_fixture(user, organisation, %{
          system_id: system.id,
          asset_id: asset.id
        })

      risk = RisksFixtures.risk_fixture(user, threat.id)
      other_threat = ThreatsFixtures.threat_fixture(user, organisation, %{name: "other"})

      assert :ok = ThreatManagement.destroy_system(system.id, actor: user)

      refute Repo.get(System, system.id)
      refute Repo.get(Asset, asset.id)
      refute Repo.get(Threat, threat.id)
      refute Repo.get(Risk, risk.id)
      assert Repo.get(Threat, other_threat.id)
    end
  end
end
