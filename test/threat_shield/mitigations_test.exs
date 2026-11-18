defmodule ThreatShield.MitigationsTest do
  alias ThreatShield.RisksFixtures
  use ThreatShield.DataCase

  alias ThreatShield.Mitigations
  alias ThreatShield.AccountsFixtures
  alias ThreatShield.OrganisationsFixtures
  alias ThreatShield.ThreatsFixtures
  alias ThreatShield.RisksFixtures

  @create_attrs %{
    name: "some name",
    description: "some description",
    estimated_cost: 42,
    probability: 120.5
  }

  defp user_risk_fixture() do
    user = AccountsFixtures.user_fixture()
    organisation = OrganisationsFixtures.organisation_fixture(user)
    threat = ThreatsFixtures.threat_fixture(user, organisation)
    risk = RisksFixtures.risk_fixture(user, threat.id, @create_attrs)
    %{user: user, risk: risk}
  end

  describe "mitigations" do
    alias ThreatShield.ThreatManagement.Mitigation

    test "create_mitigation/1 with valid data creates a mitigation" do
      valid_attrs = %{name: "some name", description: "some description"}
      %{user: user, risk: risk} = user_risk_fixture()

      assert {:ok, %Mitigation{} = mitigation} =
               Mitigations.create_mitigation(user, risk, valid_attrs)

      assert mitigation.name == "some name"
      assert mitigation.description == "some description"
      assert mitigation.is_implemented == false
    end

    test "create_mitigation/1 with invalid data returns error" do
      %{user: user, risk: risk} = user_risk_fixture()

      assert {:error, _} =
               Mitigations.create_mitigation(user, risk, %{name: nil, description: nil})
    end

    test "update_mitigation/3 does not move the mitigation to another risk" do
      %{user: user, risk: risk} = user_risk_fixture()
      %{risk: foreign_risk} = user_risk_fixture()

      {:ok, mitigation} =
        Mitigations.create_mitigation(user, risk, %{
          name: "some name",
          description: "some description",
          is_implemented: false
        })

      assert {:ok, %Mitigation{} = updated} =
               Mitigations.update_mitigation(user, mitigation, %{
                 "name" => "new name",
                 "risk_id" => foreign_risk.id
               })

      assert updated.name == "new name"
      assert Repo.get!(Mitigation, mitigation.id).risk_id == risk.id
    end
  end
end
