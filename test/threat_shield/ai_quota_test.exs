defmodule ThreatShield.AIQuotaTest do
  @moduledoc """
  The quota of the AI suggestions (`ThreatShield.Quotas.AiQuota`, the AI hook of the
  threat model library). The suggestions themselves are tested in the library.
  """
  use ThreatShield.DataCase

  alias AshThreatShield.ThreatManagement
  alias AshThreatShield.ThreatManagement.{Asset, Mitigation, Risk, Threat}
  alias ThreatShield.{AccountsFixtures, MembersFixtures, OrganisationsFixtures}
  alias ThreatShield.Quotas.Errors.QuotaExceeded
  alias ThreatShield.Quotas.QuotaManager

  setup do
    Application.put_env(:ash_threat_shield, :ai_stub_listener, self())
    on_exit(fn -> Application.delete_env(:ash_threat_shield, :ai_stub_listener) end)

    user = AccountsFixtures.user_fixture()
    organisation = OrganisationsFixtures.organisation_fixture(user, %{name: "ACME"})
    system = AshThreatShield.SystemsFixtures.system_fixture(user, organisation)
    threat = AshThreatShield.ThreatsFixtures.threat_fixture(user, organisation)
    risk = AshThreatShield.RisksFixtures.risk_fixture(user, threat.id)

    %{user: user, organisation: organisation, system: system, threat: threat, risk: risk}
  end

  defp usage(organisation) do
    {:ok, usage} = QuotaManager.get_usage(organisation, "ai_requests_per_month")
    usage
  end

  test "the suggestions record the usage and refuse a request above the quota",
       %{user: user, organisation: organisation, system: system, threat: threat, risk: risk} do
    assert {:ok, [%Asset{name: "Suggestion 1"}, %Asset{}]} =
             ThreatManagement.suggest_assets(organisation.id, %{system_id: system.id},
               actor: user
             )

    assert {:ok, [%Threat{}, %Threat{}]} =
             ThreatManagement.suggest_threats(organisation.id, actor: user)

    assert {:ok, [%Risk{}, %Risk{}]} = ThreatManagement.suggest_risks(threat.id, actor: user)

    assert {:ok, [%Mitigation{}, %Mitigation{}]} =
             ThreatManagement.suggest_mitigations(risk.id, actor: user)

    assert usage(organisation) == 4.0

    ThreatShield.Repo.update_all(ThreatShield.Accounts.Organisation,
      set: [quotas: %{"ai_requests_per_month" => 4}]
    )

    flush_requests()

    assert {:error, error} = ThreatManagement.suggest_threats(organisation.id, actor: user)
    assert QuotaExceeded.exceeded?(error)
    assert usage(organisation) == 4.0
    refute_received {:ai_request, _}
  end

  test "a suggestion refused by the policies uses no quota",
       %{organisation: organisation, threat: threat, risk: risk} do
    viewer = AccountsFixtures.user_fixture()
    MembersFixtures.membership_fixture(organisation, viewer, :viewer)
    outsider = AccountsFixtures.user_fixture()

    for actor <- [viewer, outsider] do
      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_assets(organisation.id, actor: actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_threats(organisation.id, actor: actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_risks(threat.id, actor: actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_mitigations(risk.id, actor: actor)
    end

    assert usage(organisation) == 0.0
    refute_received {:ai_request, _}
  end

  defp flush_requests do
    receive do
      {:ai_request, _} -> flush_requests()
    after
      0 -> :ok
    end
  end
end
