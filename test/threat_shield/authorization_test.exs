defmodule ThreatShield.AuthorizationTest do
  @moduledoc """
  The policies of the resources: a user reads only the records of the organisations
  where they are a member, a viewer changes nothing, and members of another
  organisation can neither read, change nor delete.
  """
  use ThreatShield.DataCase

  alias ThreatShield.{Accounts, ThreatManagement}
  alias ThreatShield.Accounts.Organisation
  alias ThreatShield.ThreatManagement.{Asset, Mitigation, Risk, System, Threat}

  alias ThreatShield.{
    AccountsFixtures,
    AssetsFixtures,
    MembersFixtures,
    MitigationsFixtures,
    OrganisationsFixtures,
    RisksFixtures,
    SystemsFixtures,
    ThreatsFixtures
  }

  setup do
    owner = AccountsFixtures.user_fixture()
    organisation = OrganisationsFixtures.organisation_fixture(owner)

    viewer = AccountsFixtures.user_fixture()
    MembersFixtures.membership_fixture(organisation, viewer, :viewer)

    editor = AccountsFixtures.user_fixture()
    MembersFixtures.membership_fixture(organisation, editor, :editor)

    # the owner of another organisation
    outsider = AccountsFixtures.user_fixture()
    other_organisation = OrganisationsFixtures.organisation_fixture(outsider)

    system = SystemsFixtures.system_fixture(owner, organisation)
    asset = AssetsFixtures.asset_fixture(owner, organisation)
    threat = ThreatsFixtures.threat_fixture(owner, organisation)
    risk = RisksFixtures.risk_fixture(owner, threat.id)
    mitigation = MitigationsFixtures.mitigation_fixture(owner, risk)

    %{
      owner: owner,
      viewer: viewer,
      editor: editor,
      outsider: outsider,
      organisation: organisation,
      other_organisation: other_organisation,
      records: %{
        System => system,
        Asset => asset,
        Threat => threat,
        Risk => risk,
        Mitigation => mitigation
      }
    }
  end

  # For each resource: the functions of the domain and the attributes of a new record
  defp resources(%{organisation: org, records: records}) do
    [
      {System, :system, %{name: "new", description: "d", organisation_id: org.id}},
      {Asset, :asset, %{name: "new", organisation_id: org.id}},
      {Threat, :threat, %{name: "new", description: "d", organisation_id: org.id}},
      {Risk, :risk, %{name: "new", description: "d", threat_id: records[Threat].id}},
      {Mitigation, :mitigation, %{name: "new", description: "d", risk_id: records[Risk].id}}
    ]
  end

  defp call(name, args), do: apply(ThreatManagement, name, args)
  defp fun(action, entity), do: String.to_existing_atom("#{action}_#{entity}")

  defp assert_denied({:error, %Ash.Error.Forbidden{}}), do: :ok

  defp assert_denied({:error, %Ash.Error.Invalid{errors: errors}}) do
    assert Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1))
  end

  defp assert_denied(other), do: flunk("expected a denial, got #{inspect(other)}")

  test "a member of another organisation can neither read, update nor delete", context do
    %{outsider: outsider, organisation: organisation, records: records} = context

    for {resource, entity, _attrs} <- resources(context) do
      record = records[resource]

      assert_denied(call(fun(:get, entity), [record.id, [actor: outsider]]))
      assert Ash.read!(resource, actor: outsider) == [], inspect(resource)

      assert call(:"list_#{entity}s", [organisation.id, [actor: outsider]]) == {:ok, []},
             inspect(resource)

      assert_denied(call(fun(:update, entity), [record, %{name: "changed"}, [actor: outsider]]))
      assert_denied(call(fun(:destroy, entity), [record.id, [actor: outsider]]))

      assert Repo.get!(resource, record.id).name == record.name
    end
  end

  test "a member of another organisation cannot create records in the organisation", context do
    for {resource, entity, attrs} <- resources(context) do
      assert {:error, %Ash.Error.Forbidden{}} =
               call(fun(:create, entity), [attrs, [actor: context.outsider]]),
             inspect(resource)
    end
  end

  test "a viewer reads, but cannot create, update or delete", context do
    %{viewer: viewer, organisation: organisation, records: records} = context

    for {resource, entity, attrs} <- resources(context) do
      record = records[resource]

      assert {:ok, %{id: id}} = call(fun(:get, entity), [record.id, [actor: viewer]])
      assert id == record.id
      assert {:ok, [_ | _]} = call(:"list_#{entity}s", [organisation.id, [actor: viewer]])

      assert {:error, %Ash.Error.Forbidden{}} =
               call(fun(:create, entity), [attrs, [actor: viewer]])

      assert_denied(call(fun(:update, entity), [record, %{name: "changed"}, [actor: viewer]]))
      assert_denied(call(fun(:destroy, entity), [record.id, [actor: viewer]]))

      assert Repo.get!(resource, record.id).name == record.name
    end
  end

  test "an editor creates, updates and deletes", context do
    %{editor: editor, records: records} = context

    for {resource, entity, attrs} <- resources(context) do
      assert {:ok, created} = call(fun(:create, entity), [attrs, [actor: editor]])

      assert {:ok, %{name: "changed"}} =
               call(fun(:update, entity), [created, %{name: "changed"}, [actor: editor]])

      assert :ok = call(fun(:destroy, entity), [created.id, [actor: editor]])
      refute Repo.get(resource, created.id)
      assert Repo.get(resource, records[resource].id)
    end
  end

  test "without an actor, nothing is readable or writable", context do
    for {resource, entity, attrs} <- resources(context) do
      assert Ash.read!(resource) == [], inspect(resource)
      assert {:error, %Ash.Error.Forbidden{}} = call(fun(:create, entity), [attrs, []])
    end
  end

  describe "organisations" do
    test "a member of another organisation can neither read, update nor delete it", %{
      outsider: outsider,
      organisation: organisation
    } do
      assert_denied(Accounts.get_organisation(organisation.id, actor: outsider))
      assert [%Organisation{id: other_id}] = Accounts.list_organisations!(actor: outsider)
      refute other_id == organisation.id

      assert_denied(Accounts.update_organisation(organisation, %{name: "x"}, actor: outsider))
      assert_denied(Accounts.destroy_organisation(organisation.id, actor: outsider))
      assert Repo.get!(Organisation, organisation.id).name == organisation.name
    end

    test "a viewer reads, but cannot update or delete it",
         %{viewer: viewer, organisation: organisation} do
      assert {:ok, %Organisation{}} = Accounts.get_organisation(organisation.id, actor: viewer)
      assert_denied(Accounts.update_organisation(organisation, %{name: "x"}, actor: viewer))
      assert_denied(Accounts.destroy_organisation(organisation.id, actor: viewer))
      assert Repo.get(Organisation, organisation.id)
    end

    test "an editor updates, but cannot delete it", %{editor: editor, organisation: organisation} do
      assert {:ok, %Organisation{name: "x"}} =
               Accounts.update_organisation(organisation, %{name: "x"}, actor: editor)

      assert_denied(Accounts.destroy_organisation(organisation.id, actor: editor))
      assert Repo.get(Organisation, organisation.id)
    end

    test "an owner deletes it with its content",
         %{owner: owner, organisation: organisation, records: records} do
      assert :ok = Accounts.destroy_organisation(organisation.id, actor: owner)
      refute Repo.get(Organisation, organisation.id)
      refute Repo.get(Mitigation, records[Mitigation].id)
    end
  end

  test "the quota usage is not accessible to actors",
       %{owner: owner, organisation: organisation} do
    alias ThreatShield.Quotas.{QuotaManager, QuotaUsage}

    {:ok, _usage} = QuotaManager.add_usage(organisation, owner, :ai_requests_per_month, 1.0)

    assert Ash.read!(QuotaUsage, actor: owner) == []

    assert {:error, %Ash.Error.Forbidden{}} =
             QuotaUsage
             |> Ash.Changeset.for_create(
               :create,
               %{organisation_id: organisation.id, quota_type: "x", amount: -100.0},
               actor: owner
             )
             |> Ash.create()
  end
end
