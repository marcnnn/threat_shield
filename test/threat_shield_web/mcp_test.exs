defmodule ThreatShieldWeb.McpTest do
  use ThreatShieldWeb.ConnCase

  alias ThreatShield.{AccountsFixtures, MembersFixtures, OrganisationsFixtures}
  alias ThreatShield.{RisksFixtures, SystemsFixtures, ThreatsFixtures}
  alias ThreatShield.Repo
  alias ThreatShield.ThreatManagement.{Mitigation, System, Threat}

  @tools ~w(
    list_organisations threat_model_context risk_summary
    list_systems create_system update_system
    list_assets create_asset update_asset
    list_threats create_threat update_threat
    list_risks create_risk update_risk
    list_mitigations create_mitigation update_mitigation
  )

  setup do
    user = AccountsFixtures.user_fixture()
    organisation = OrganisationsFixtures.organisation_fixture(user, %{name: "ACME"})
    system = SystemsFixtures.system_fixture(user, organisation, %{name: "Web shop"})

    threat =
      ThreatsFixtures.threat_fixture(user, organisation, %{
        name: "Data theft",
        system_id: system.id
      })

    risk = RisksFixtures.risk_fixture(user, threat.id, %{name: "Fine"})

    other_user = AccountsFixtures.user_fixture()
    other_organisation = OrganisationsFixtures.organisation_fixture(other_user, %{name: "Other"})

    other_threat =
      ThreatsFixtures.threat_fixture(other_user, other_organisation, %{name: "Secret threat"})

    %{
      user: user,
      key: AccountsFixtures.api_key_fixture(user),
      organisation: organisation,
      system: system,
      threat: threat,
      risk: risk,
      other_organisation: other_organisation,
      other_threat: other_threat
    }
  end

  defp rpc(conn, key, method, params \\ %{}) do
    conn
    |> then(fn conn ->
      if key, do: put_req_header(conn, "authorization", "Bearer " <> key), else: conn
    end)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json, text/event-stream")
    |> post("/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: method, params: params}))
  end

  defp call_tool(conn, key, name, arguments) do
    response =
      conn |> rpc(key, "tools/call", %{name: name, arguments: arguments}) |> json_response(200)

    %{"result" => %{"isError" => is_error, "content" => [%{"text" => text}]}} = response
    {if(is_error, do: :error, else: :ok), text}
  end

  defp call_tool!(conn, key, name, arguments) do
    {:ok, text} = call_tool(conn, key, name, arguments)
    Jason.decode!(text)
  end

  describe "authentication" do
    test "initialize names the server", %{conn: conn, key: key} do
      response =
        conn
        |> rpc(key, "initialize", %{
          protocolVersion: "2025-03-26",
          capabilities: %{},
          clientInfo: %{name: "test", version: "1"}
        })
        |> json_response(200)

      assert %{"serverInfo" => %{"name" => "ThreatShield"}, "instructions" => instructions} =
               response["result"]

      assert instructions =~ "threat_model_context"
    end

    test "a request without a key is unauthorized", %{conn: conn} do
      assert conn |> rpc(nil, "tools/list") |> response(401)
    end

    test "a request with an invalid key is unauthorized", %{conn: conn, key: key} do
      assert conn |> rpc("threatshield_invalid", "tools/list") |> response(401)
      assert conn |> rpc(key <> "x", "tools/list") |> response(401)

      conn = put_req_header(conn, "authorization", "Basic " <> key)
      assert conn |> rpc(nil, "tools/list") |> response(401)
    end

    test "a request with an expired key is unauthorized", %{conn: conn, user: user} do
      expired = AccountsFixtures.api_key_fixture(user, -1)
      assert conn |> rpc(expired, "tools/list") |> response(401)
    end

    test "a request with a revoked key is unauthorized", %{conn: conn, user: user, key: key} do
      [api_key] = ThreatShield.Accounts.list_api_keys!(actor: user)
      :ok = ThreatShield.Accounts.revoke_api_key!(api_key, actor: user)

      assert conn |> rpc(key, "tools/list") |> response(401)
    end
  end

  test "tools/list returns the tools with descriptions", %{conn: conn, key: key} do
    %{"result" => %{"tools" => tools}} = conn |> rpc(key, "tools/list") |> json_response(200)

    assert tools |> Enum.map(& &1["name"]) |> Enum.sort() == Enum.sort(@tools)

    for tool <- tools do
      assert tool["description"] =~ ~r/\w+/, "#{tool["name"]} has no description"
    end

    context = Enum.find(tools, &(&1["name"] == "threat_model_context"))

    assert %{"organisation_id" => %{"description" => "The id of the organisation."}} =
             context["inputSchema"]["properties"]["input"]["properties"]
  end

  describe "reads" do
    test "list_organisations returns only the organisations of the user",
         %{conn: conn, key: key, organisation: organisation} do
      assert [%{"id" => id, "name" => "ACME", "threat_count" => 1}] =
               call_tool!(conn, key, "list_organisations", %{})

      assert id == organisation.id
    end

    test "list_threats returns no threats of another organisation",
         %{conn: conn, key: key, organisation: organisation, other_organisation: other} do
      assert [%{"name" => "Data theft", "system_name" => "Web shop"}] =
               call_tool!(conn, key, "list_threats", %{input: %{organisation_id: organisation.id}})

      assert [] = call_tool!(conn, key, "list_threats", %{input: %{organisation_id: other.id}})

      # the unfiltered read of the threats is not a tool, and a filter does not help
      assert [] =
               call_tool!(conn, key, "list_threats", %{
                 input: %{organisation_id: other.id},
                 filter: %{name: %{eq: "Secret threat"}}
               })
    end

    test "threat_model_context describes the model of the organisation",
         %{conn: conn, key: key, organisation: organisation, threat: threat, risk: risk} do
      text =
        call_tool!(conn, key, "threat_model_context", %{
          input: %{organisation_id: organisation.id, risk_id: risk.id}
        })

      assert text =~ ~s(The name of the organisation is "ACME".)
      assert text =~ ~s(The name of the system is "Web shop".)
      assert text =~ ~s(The name of the risk is "Fine".)

      text =
        call_tool!(conn, key, "threat_model_context", %{
          input: %{organisation_id: organisation.id}
        })

      assert text =~ "- Data theft (id #{threat.id})"
    end

    test "threat_model_context refuses another organisation and foreign records",
         %{
           conn: conn,
           key: key,
           user: user,
           organisation: organisation,
           other_organisation: other,
           other_threat: other_threat
         } do
      assert {:error, _} =
               call_tool(conn, key, "threat_model_context", %{input: %{organisation_id: other.id}})

      assert {:error, _} =
               call_tool(conn, key, "threat_model_context", %{
                 input: %{organisation_id: organisation.id, threat_id: other_threat.id}
               })

      # a threat of a second organisation of the user does not belong to the first one
      second = OrganisationsFixtures.organisation_fixture(user, %{name: "Second"})
      second_threat = ThreatsFixtures.threat_fixture(user, second, %{name: "Elsewhere"})

      assert {:error, text} =
               call_tool(conn, key, "threat_model_context", %{
                 input: %{organisation_id: organisation.id, threat_id: second_threat.id}
               })

      assert text =~ "does not belong to the organisation"
    end

    test "risk_summary sums up the risks of the organisation",
         %{conn: conn, key: key, organisation: organisation, other_organisation: other} do
      assert %{"risk_count" => 1, "threat_count" => 1, "risks_by_status" => by_status} =
               call_tool!(conn, key, "risk_summary", %{input: %{organisation_id: organisation.id}})

      assert by_status["identified"] + by_status["assessed"] + by_status["mitigated"] +
               by_status["accepted"] == 1

      assert {:error, _} =
               call_tool(conn, key, "risk_summary", %{input: %{organisation_id: other.id}})
    end
  end

  describe "writes" do
    test "create and update records of the organisation",
         %{conn: conn, key: key, organisation: organisation, system: system} do
      assert %{"id" => asset_id} =
               call_tool!(conn, key, "create_asset", %{
                 input: %{
                   name: "Customer data",
                   description: "Names and addresses",
                   organisation_id: organisation.id,
                   system_id: system.id
                 }
               })

      assert %{"id" => threat_id} =
               call_tool!(conn, key, "create_threat", %{
                 input: %{
                   name: "Phishing",
                   description: "Mails that steal passwords",
                   organisation_id: organisation.id,
                   asset_id: asset_id
                 }
               })

      assert %{"id" => risk_id} =
               call_tool!(conn, key, "create_risk", %{
                 input: %{name: "Loss", description: "Data is lost", threat_id: threat_id}
               })

      assert %{"id" => mitigation_id} =
               call_tool!(conn, key, "create_mitigation", %{
                 input: %{name: "Training", description: "Train the staff", risk_id: risk_id}
               })

      assert %{"name" => "Phishing mails"} =
               call_tool!(conn, key, "update_threat", %{
                 id: threat_id,
                 input: %{name: "Phishing mails"}
               })

      assert %Mitigation{name: "Training"} = Repo.get!(Mitigation, mitigation_id)
      assert %Threat{name: "Phishing mails"} = Repo.get!(Threat, threat_id)
    end

    test "creating in another organisation is forbidden",
         %{conn: conn, key: key, other_organisation: other, other_threat: other_threat} do
      assert {:error, text} =
               call_tool(conn, key, "create_system", %{
                 input: %{name: "Intruder", description: "x", organisation_id: other.id}
               })

      assert text =~ ~r/forbidden/i
      refute Repo.get_by(System, name: "Intruder")

      assert {:error, _} =
               call_tool(conn, key, "create_risk", %{
                 input: %{name: "Intruder", description: "x", threat_id: other_threat.id}
               })

      assert {:error, _} =
               call_tool(conn, key, "update_threat", %{
                 id: other_threat.id,
                 input: %{name: "Changed"}
               })

      assert %Threat{name: "Secret threat"} = Repo.get!(Threat, other_threat.id)
    end

    test "a viewer may read but not write",
         %{conn: conn, organisation: organisation, threat: threat} do
      viewer = AccountsFixtures.user_fixture()
      MembersFixtures.membership_fixture(organisation, viewer, :viewer)
      key = AccountsFixtures.api_key_fixture(viewer)

      assert [%{"name" => "Data theft"}] =
               call_tool!(conn, key, "list_threats", %{input: %{organisation_id: organisation.id}})

      assert {:error, _} =
               call_tool(conn, key, "update_threat", %{id: threat.id, input: %{name: "Changed"}})

      assert {:error, _} =
               call_tool(conn, key, "create_threat", %{
                 input: %{name: "New", description: "x", organisation_id: organisation.id}
               })

      assert %Threat{name: "Data theft"} = Repo.get!(Threat, threat.id)
    end
  end

  test "there are no tools to delete or to manage members", %{conn: conn, key: key} do
    response =
      conn
      |> rpc(key, "tools/call", %{name: "destroy_threat", arguments: %{id: 1}})
      |> json_response(200)

    assert %{"error" => %{"message" => "Tool not found: destroy_threat"}} = response
  end
end
