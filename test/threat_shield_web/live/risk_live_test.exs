defmodule ThreatShieldWeb.RiskLiveTest do
  use ThreatShieldWeb.ConnCase

  import Phoenix.LiveViewTest
  import AshThreatShield.RisksFixtures

  alias AshThreatShield.ThreatsFixtures
  alias ThreatShield.OrganisationsFixtures

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

    test "links a risk of a threat with an asset but without a system",
         %{conn: conn, user: user, organisation: organisation} do
      asset =
        AshThreatShield.AssetsFixtures.asset_fixture(user, organisation, %{name: "Laptop"})

      threat =
        ThreatsFixtures.threat_fixture(user, organisation, %{name: "Theft", asset_id: asset.id})

      risk = risk_fixture(user, threat.id, %{name: "Lost laptop", severity: 2.0})

      {:ok, view, html} = live(conn, ~p"/organisations/#{organisation.id}/risk-board")
      assert html =~ "Lost laptop"

      render_click(view, "risk-selected", %{"risk-id" => to_string(risk.id)})

      assert_redirect(
        view,
        ~p"/organisations/#{organisation.id}/threats/#{threat.id}/risks/#{risk.id}"
      )
    end
  end

  test "shows the frequency of a risk with its decimals",
       %{conn: conn, user: user} do
    organisation = OrganisationsFixtures.organisation_fixture(user)
    threat = ThreatsFixtures.threat_fixture(user, organisation)
    risk = risk_fixture(user, threat.id, %{name: "Rare", probability: 0.3})

    {:ok, _view, html} =
      live(conn, ~p"/organisations/#{organisation.id}/threats/#{threat.id}/risks/#{risk.id}")

    assert html =~ "0,3"
  end
end
