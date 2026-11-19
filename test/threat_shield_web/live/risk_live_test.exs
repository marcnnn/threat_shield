defmodule ThreatShieldWeb.RiskLiveTest do
  use ThreatShieldWeb.ConnCase

  import Phoenix.LiveViewTest
  import AshThreatShield.RisksFixtures

  alias ThreatShield.OrganisationsFixtures
  alias AshThreatShield.ThreatsFixtures

  setup :register_and_log_in_user

  describe "risk board" do
    setup %{user: user} do
      organisation = OrganisationsFixtures.organisation_fixture(user)
      threat = ThreatsFixtures.threat_fixture(user, organisation)

      risk =
        risk_fixture(user, threat.id, %{
          name: "Costly risk",
          estimated_cost: 1000,
          probability: 2.0,
          severity: 4.0
        })

      risk_fixture(user, threat.id, %{name: "Unrated risk", severity: nil, estimated_cost: nil})

      %{organisation: organisation, risk: risk}
    end

    test "shows the summary and the top risks",
         %{conn: conn, organisation: organisation, risk: risk} do
      {:ok, view, html} = live(conn, ~p"/organisations/#{organisation.id}/risk-board")

      assert html =~ "Risk summary"
      assert html =~ "Costly risk"
      assert html =~ "Unrated risk"

      # the risk with a severity comes before the one without
      [_, tables] = String.split(html, "Top 10 risks by severity")
      [severity_table, _] = String.split(tables, "Top 10 risks by costs")
      {costly, _} = :binary.match(severity_table, "Costly risk")
      {unrated, _} = :binary.match(severity_table, "Unrated risk")
      assert costly < unrated

      render_click(view, "risk-selected", %{"risk-id" => to_string(risk.id)})

      assert_redirect(
        view,
        ~p"/organisations/#{organisation.id}/threats/#{risk.threat_id}/risks/#{risk.id}"
      )
    end
  end
end
