defmodule AshThreatShield.RiskSummaryTest do
  use AshThreatShield.DataCase

  alias AshThreatShield.MitigationsFixtures
  alias AshThreatShield.RisksFixtures
  alias AshThreatShield.ThreatManagement
  alias AshThreatShield.ThreatsFixtures

  setup do
    user = user_fixture()
    organisation = organisation_fixture(user)
    threat = ThreatsFixtures.threat_fixture(user, organisation)

    # a risk of another organisation of the user is not counted
    other = organisation_fixture(user)
    other_threat = ThreatsFixtures.threat_fixture(user, other)
    RisksFixtures.risk_fixture(user, other_threat.id, %{severity: 5.0, estimated_cost: 999})

    %{user: user, organisation: organisation, threat: threat}
  end

  defp risk(user, threat, attrs), do: RisksFixtures.risk_fixture(user, threat.id, attrs)

  test "sums up the costs and counts the states",
       %{user: user, organisation: organisation, threat: threat} do
    mitigated = risk(user, threat, %{estimated_cost: 100, probability: 2.0, status: :mitigated})
    risk(user, threat, %{estimated_cost: 10, probability: 1.0, status: :assessed})
    risk(user, threat, %{estimated_cost: nil, probability: 1.0})
    MitigationsFixtures.mitigation_fixture(user, mitigated, %{status: :verified})

    assert {:ok, summary} = ThreatManagement.risk_summary(organisation.id, actor: user)

    assert %{
             threat_count: 1,
             risk_count: 3,
             mitigation_count: 1,
             total_risk_cost: 210,
             mitigated_risk_cost: 200,
             unmitigated_risk_cost: 10
           } = summary

    assert summary.risks_by_status == %{identified: 1, assessed: 1, mitigated: 1, accepted: 0}
    assert summary.mitigations_by_status.verified == 1
    assert summary.mitigations_by_status.open == 0
  end

  test "an organisation without risks has zero costs",
       %{user: user} do
    empty = organisation_fixture(user)

    assert {:ok, %{total_risk_cost: 0, top_risks_by_severity: [], top_risks_by_cost: []}} =
             ThreatManagement.risk_summary(empty.id, actor: user)
  end

  test "lists the ten most severe and the ten most costly risks, without severity last",
       %{user: user, organisation: organisation, threat: threat} do
    unrated = risk(user, threat, %{name: "unrated", severity: nil, estimated_cost: nil})

    for i <- 1..11 do
      risk(user, threat, %{name: "risk #{i}", severity: i / 5, estimated_cost: i})
    end

    assert {:ok, summary} = ThreatManagement.risk_summary(organisation.id, actor: user)

    by_severity = Enum.map(summary.top_risks_by_severity, & &1.name)
    assert length(by_severity) == 10
    assert hd(by_severity) == "risk 11"
    refute unrated.name in by_severity

    by_cost = Enum.map(summary.top_risks_by_cost, & &1.name)
    assert by_cost == for(i <- 11..2//-1, do: "risk #{i}")

    # with fewer rated risks, the unrated one comes last
    for %{id: id} <- summary.top_risks_by_severity,
        do: ThreatManagement.destroy_risk!(id, actor: user)

    assert {:ok, summary} = ThreatManagement.risk_summary(organisation.id, actor: user)
    assert Enum.map(summary.top_risks_by_severity, & &1.name) == ["risk 1", "unrated"]
  end
end
