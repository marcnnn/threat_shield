defmodule ThreatShield.AITest do
  use ThreatShield.DataCase

  alias ThreatShield.AccountsFixtures
  alias ThreatShield.AssetsFixtures
  alias ThreatShield.MitigationsFixtures
  alias ThreatShield.OrganisationsFixtures
  alias ThreatShield.RisksFixtures
  alias ThreatShield.ThreatsFixtures

  alias ThreatShield.AI
  alias ThreatShield.Scope
  alias ThreatShield.{Accounts, ThreatManagement}
  alias ThreatShield.ThreatManagement.Asset
  alias ThreatShield.ThreatManagement.Mitigation
  alias ThreatShield.ThreatManagement.Risk
  alias ThreatShield.ThreatManagement.Threat
  alias ThreatShield.ThreatManagement.Description

  setup do
    Application.put_env(:threat_shield, :ai_stub_listener, self())
    on_exit(fn -> Application.delete_env(:threat_shield, :ai_stub_listener) end)

    user = AccountsFixtures.user_fixture()
    organisation = OrganisationsFixtures.organisation_fixture(user, %{name: "ACME"})

    system =
      ThreatShield.SystemsFixtures.system_fixture(user, organisation, %{
        name: "Web shop",
        description: "Sells products",
        attributes: %{"Database" => "Postgres"}
      })

    asset =
      AssetsFixtures.asset_fixture(user, organisation, %{
        name: "Customer data",
        system_id: system.id
      })

    threat =
      ThreatsFixtures.threat_fixture(user, organisation, %{
        name: "Data theft",
        system_id: system.id,
        asset_id: asset.id
      })

    risk = RisksFixtures.risk_fixture(user, threat.id, %{name: "Fine by the authority"})
    MitigationsFixtures.mitigation_fixture(user, risk, %{name: "Encrypt the database"})

    %{
      user: user,
      organisation: organisation,
      system: system,
      asset: asset,
      threat: threat,
      risk: risk
    }
  end

  defp get_organisation!(user, id) do
    Accounts.get_organisation!(id,
      actor: user,
      load: [:memberships, :systems, threats: [:system, :asset], assets: [:system]]
    )
  end

  defp prompts() do
    assert_received {:ai_request,
                     [
                       %{role: "system", content: system_prompt},
                       %{role: "user", content: user_prompt}
                     ]}

    {system_prompt, user_prompt}
  end

  describe "the suggestion actions" do
    defp usage(organisation),
      do: ThreatShield.Quotas.QuotaManager.get_usage(organisation, "ai_requests_per_month")

    test "record the usage and refuse a request above the quota",
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

      assert {:error, error} = ThreatManagement.suggest_threats(organisation.id, actor: user)
      assert ThreatShield.Quotas.Errors.QuotaExceeded.exceeded?(error)
      assert usage(organisation) == 4.0
    end

    test "are refused for a viewer, without using the quota or the language model",
         %{organisation: organisation, threat: threat, risk: risk} do
      viewer = AccountsFixtures.user_fixture()
      ThreatShield.MembersFixtures.membership_fixture(organisation, viewer, :viewer)

      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_assets(organisation.id, actor: viewer)

      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_threats(organisation.id, actor: viewer)

      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_risks(threat.id, actor: viewer)

      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_mitigations(risk.id, actor: viewer)

      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_threats(organisation.id)

      assert usage(organisation) == 0.0
      refute_received {:ai_request, _}
    end

    test "are refused for another organisation and for a record of another organisation",
         %{user: user, organisation: organisation, threat: threat} do
      outsider = AccountsFixtures.user_fixture()
      other = OrganisationsFixtures.organisation_fixture(outsider)
      other_system = ThreatShield.SystemsFixtures.system_fixture(outsider, other)

      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_threats(organisation.id, actor: outsider)

      assert {:error, %Ash.Error.Forbidden{}} =
               ThreatManagement.suggest_risks(threat.id, actor: outsider)

      assert {:error, _} =
               ThreatManagement.suggest_threats(organisation.id, %{system_id: other_system.id},
                 actor: user
               )

      assert usage(organisation) == 0.0
      refute_received {:ai_request, _}
    end
  end

  test "suggest_assets/1 for an organisation", %{user: user, organisation: organisation} do
    organisation = get_organisation!(user, organisation.id)

    assert [%Asset{name: "Suggestion 1", description: "Description 1"}, %Asset{}] =
             AI.suggest_assets(Scope.for(user, organisation))

    {system_prompt, user_prompt} = prompts()

    assert system_prompt =~ ~s(You are a threat modelling assistant at "ACME".)
    assert system_prompt =~ ~s(The name of the system is "Web shop".)
    assert user_prompt =~ ~s({"assets": [{"name": _, "description": _}, _ ]})
    assert user_prompt =~ "I already know about the following assets:\n\nCustomer data"

    assert user_prompt =~
             "Please suggest five additional assets that are different from the existing ones.\n"
  end

  test "suggest_assets/1 for a system", %{user: user, organisation: organisation, system: system} do
    organisation = get_organisation!(user, organisation.id)

    system =
      ThreatManagement.get_system!(system.id,
        actor: user,
        load: [:assets, :threats, organisation: [:systems]]
      )

    assert [%Asset{}, %Asset{}] = AI.suggest_assets(Scope.for(user, organisation, system: system))

    {_system_prompt, user_prompt} = prompts()

    assert user_prompt =~ "Assets are valuable resources or data for a particular system"
    assert user_prompt =~ "Customer data"
    assert user_prompt =~ ~s(The assets should be specific to the system "Web shop".)
  end

  test "suggest_threats/1 for an organisation, a system, and an asset",
       %{user: user, organisation: organisation, system: system, asset: asset} do
    organisation = get_organisation!(user, organisation.id)

    system =
      ThreatManagement.get_system!(system.id,
        actor: user,
        load: [:assets, :threats, organisation: [:systems]]
      )

    asset =
      ThreatManagement.get_asset!(asset.id,
        actor: user,
        load: [:system, :threats, organisation: [:systems]]
      )

    assert [%Threat{name: "Suggestion 1"}, %Threat{}] =
             AI.suggest_threats(Scope.for(user, organisation))

    {_system_prompt, user_prompt} = prompts()
    assert user_prompt =~ ~s({"threats": [)
    assert user_prompt =~ "I already know about the following threats:\n\nData theft"
    refute user_prompt =~ "should be specific"

    assert [%Threat{}, %Threat{}] =
             AI.suggest_threats(Scope.for(user, organisation, system: system))

    {_system_prompt, user_prompt} = prompts()
    assert user_prompt =~ "The threats should be specific to the system 'Web shop'"

    assert [%Threat{}, %Threat{}] =
             AI.suggest_threats(Scope.for(user, organisation, asset: asset))

    {_system_prompt, user_prompt} = prompts()
    assert user_prompt =~ "The threats should be specific to the asset 'Customer data'"

    assert [%Threat{}, %Threat{}] =
             AI.suggest_threats(Scope.for(user, organisation, system: system, asset: asset))

    {_system_prompt, user_prompt} = prompts()
    assert user_prompt =~ "'Web shop'  and the asset 'Customer data'"
  end

  test "suggest_risks_for_threat/2", %{user: user, organisation: organisation, threat: threat} do
    organisation = get_organisation!(user, organisation.id)

    threat =
      ThreatManagement.get_threat!(threat.id,
        actor: user,
        load: [risks: :mitigations, organisation: [:systems]]
      )

    assert [%Risk{name: "Suggestion 1"}, %Risk{}] =
             AI.suggest_risks_for_threat(Scope.for(user, organisation), threat)

    {system_prompt, user_prompt} = prompts()

    assert system_prompt =~ ~s(at "ACME")
    assert user_prompt =~ ~s({"risks": [)
    assert user_prompt =~ "I already know about the following risks:\n\nFine by the authority"
    assert user_prompt =~ ~s(The risks should relate exclusively to the threat "Data theft".)
  end

  test "suggest_mitigations_for_risk/2", %{user: user, organisation: organisation, risk: risk} do
    organisation = get_organisation!(user, organisation.id)

    risk =
      ThreatManagement.get_risk!(risk.id,
        actor: user,
        load: [:mitigations, threat: [:system, organisation: [:systems]]]
      )

    assert [%Mitigation{name: "Suggestion 1"}, %Mitigation{}] =
             AI.suggest_mitigations_for_risk(Scope.for(user, organisation), risk)

    {_system_prompt, user_prompt} = prompts()

    assert user_prompt =~ ~s({"mitigations": [)

    assert user_prompt =~
             "I already know about the following mitigations:\n\nEncrypt the database"

    assert user_prompt =~
             ~s(exclusively to the risk "Fine by the authority" and the threat "Data theft".)

    assert user_prompt =~ ~s(The only relvant system in this context is "Web shop".)
  end

  test "an error of the provider is returned", %{user: user, organisation: organisation} do
    Application.put_env(:threat_shield, :ai_stub_result, {:error, :timeout})
    on_exit(fn -> Application.delete_env(:threat_shield, :ai_stub_result) end)

    organisation = get_organisation!(user, organisation.id)
    assert {:error, :timeout} = AI.suggest_threats(Scope.for(user, organisation))
  end

  test "an answer that is not the expected JSON gives no suggestions",
       %{user: user, organisation: organisation} do
    Application.put_env(:threat_shield, :ai_stub_result, {:ok, ~s({"other": []})})
    on_exit(fn -> Application.delete_env(:threat_shield, :ai_stub_result) end)

    organisation = get_organisation!(user, organisation.id)
    assert [] = AI.suggest_threats(Scope.for(user, organisation))
  end

  describe "the prompts and the description need no language model" do
    test "Prompts.threats/1 is the prompt that the provider gets",
         %{user: user, organisation: organisation} do
      organisation = get_organisation!(user, organisation.id)
      scope = Scope.for(user, organisation)

      assert {:threats, system_prompt, user_prompt} = AI.Prompts.threats(scope)
      refute_received {:ai_request, _}

      AI.suggest_threats(scope)
      assert {^system_prompt, ^user_prompt} = prompts()
    end

    test "Description.threat_model/1 describes the records in focus",
         %{user: user, organisation: organisation, risk: risk} do
      organisation = get_organisation!(user, organisation.id)

      risk =
        ThreatManagement.get_risk!(risk.id,
          actor: user,
          load: [:mitigations, threat: [:system, :asset]]
        )

      text =
        Description.threat_model(%{
          organisation: organisation,
          system: risk.threat.system,
          threat: risk.threat,
          risk: risk
        })

      assert text =~ ~s(The name of the organisation is "ACME".)
      assert text =~ "## System in focus"
      assert text =~ ~s(The name of the threat is "Data theft".)
      assert text =~ ~s(The name of the risk is "Fine by the authority".)
      assert text =~ "## Mitigations of the risk\n\n- Encrypt the database (id "
      refute text =~ "## Threats of the organisation"

      text = Description.threat_model(%{organisation: organisation})
      assert text =~ "## Threats of the organisation\n\n- Data theft (id #{risk.threat.id})"
      assert text =~ "## Assets of the organisation\n\n- Customer data (id "
    end
  end
end
