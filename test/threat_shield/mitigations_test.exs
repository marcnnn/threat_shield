defmodule ThreatShield.MitigationsTest do
  use ThreatShield.DataCase

  alias ThreatShield.AccountsFixtures
  alias ThreatShield.OrganisationsFixtures
  alias ThreatShield.RisksFixtures
  alias ThreatShield.ThreatsFixtures
  alias ThreatShield.ThreatManagement
  alias ThreatShield.ThreatManagement.Mitigation

  defp user_risk_fixture() do
    user = AccountsFixtures.user_fixture()
    organisation = OrganisationsFixtures.organisation_fixture(user)
    threat = ThreatsFixtures.threat_fixture(user, organisation)
    risk = RisksFixtures.risk_fixture(user, threat.id)
    %{user: user, risk: risk}
  end

  describe "mitigations" do
    test "create_mitigation with valid data creates a mitigation" do
      %{user: user, risk: risk} = user_risk_fixture()

      assert {:ok, %Mitigation{} = mitigation} =
               ThreatManagement.create_mitigation(
                 %{name: "some name", description: "some description", risk_id: risk.id},
                 actor: user
               )

      assert mitigation.name == "some name"
      assert mitigation.is_implemented == false
    end

    test "create_mitigation with invalid data returns error" do
      %{user: user, risk: risk} = user_risk_fixture()

      assert {:error, _} =
               ThreatManagement.create_mitigation(
                 %{name: nil, description: nil, risk_id: risk.id},
                 actor: user
               )
    end

    test "is_implemented follows the status" do
      %{user: user, risk: risk} = user_risk_fixture()

      {:ok, mitigation} =
        ThreatManagement.create_mitigation(
          %{name: "n", description: "d", risk_id: risk.id, status: :verified},
          actor: user
        )

      assert mitigation.is_implemented

      {:ok, mitigation} =
        ThreatManagement.update_mitigation(mitigation, %{status: :failed}, actor: user)

      refute mitigation.is_implemented
      refute Repo.get!(Mitigation, mitigation.id).is_implemented

      {:ok, mitigation} =
        ThreatManagement.update_mitigation(mitigation, %{status: :implemented}, actor: user)

      assert Repo.get!(Mitigation, mitigation.id).is_implemented

      assert {:error, %Ash.Error.Invalid{}} =
               ThreatManagement.update_mitigation(mitigation, %{is_implemented: false},
                 actor: user
               )
    end

    test "update_mitigation does not move the mitigation to another risk" do
      %{user: user, risk: risk} = user_risk_fixture()
      %{risk: foreign_risk} = user_risk_fixture()

      {:ok, mitigation} =
        ThreatManagement.create_mitigation(
          %{name: "some name", description: "some description", risk_id: risk.id},
          actor: user
        )

      assert {:error, %Ash.Error.Invalid{}} =
               ThreatManagement.update_mitigation(
                 mitigation,
                 %{"name" => "new name", "risk_id" => foreign_risk.id},
                 actor: user
               )

      assert Repo.get!(Mitigation, mitigation.id).risk_id == risk.id
    end
  end
end
