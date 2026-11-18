defmodule ThreatShield.RisksTest do
  use ThreatShield.DataCase

  alias ThreatShield.AccountsFixtures
  alias ThreatShield.OrganisationsFixtures
  alias ThreatShield.RisksFixtures
  alias ThreatShield.ThreatsFixtures
  alias ThreatShield.ThreatManagement
  alias ThreatShield.ThreatManagement.Risk

  setup do
    user = AccountsFixtures.user_fixture()
    organisation = OrganisationsFixtures.organisation_fixture(user)
    threat = ThreatsFixtures.threat_fixture(user, organisation)
    %{user: user, organisation: organisation, threat: threat}
  end

  test "create_risk creates a risk", %{user: user, threat: threat} do
    assert {:ok, %Risk{status: :identified}} =
             ThreatManagement.create_risk(
               %{name: "some name", description: "some description", threat_id: threat.id},
               actor: user
             )
  end

  test "the estimated risk cost is the cost per incident times the incidents per year",
       %{user: user, threat: threat} do
    risk = RisksFixtures.risk_fixture(user, threat.id, %{estimated_cost: 1000, probability: 2.5})
    no_cost = RisksFixtures.risk_fixture(user, threat.id, %{estimated_cost: nil})

    assert %Risk{estimated_risk_cost: 2500} =
             ThreatManagement.get_risk!(risk.id, actor: user, load: [:estimated_risk_cost])

    assert %Risk{estimated_risk_cost: nil} =
             ThreatManagement.get_risk!(no_cost.id, actor: user, load: [:estimated_risk_cost])
  end

  test "list_risks returns the risks of the organisation",
       %{user: user, organisation: organisation, threat: threat} do
    risk = RisksFixtures.risk_fixture(user, threat.id)

    assert [%Risk{id: id}] = ThreatManagement.list_risks!(organisation.id, actor: user)
    assert id == risk.id
  end
end
