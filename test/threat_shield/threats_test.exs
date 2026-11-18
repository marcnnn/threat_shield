defmodule ThreatShield.ThreatsTest do
  use ThreatShield.DataCase

  alias ThreatShield.AccountsFixtures
  alias ThreatShield.AssetsFixtures
  alias ThreatShield.MembersFixtures
  alias ThreatShield.OrganisationsFixtures
  alias ThreatShield.SystemsFixtures
  alias ThreatShield.ThreatManagement
  alias ThreatShield.ThreatManagement.Threat

  @valid_attrs %{name: "some name", description: "some description"}

  defp create_threat(user, organisation, attrs) do
    attrs
    |> Map.put(:organisation_id, organisation.id)
    |> ThreatManagement.create_threat(actor: user)
  end

  describe "threats" do
    test "create_threat with valid data creates a threat" do
      user = AccountsFixtures.user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(user)

      assert {:ok, %Threat{} = threat} = create_threat(user, organisation, @valid_attrs)
      assert threat.organisation_id == organisation.id
    end

    test "is not allowed for a viewer" do
      user = AccountsFixtures.user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(user)
      viewer = AccountsFixtures.user_fixture()
      MembersFixtures.membership_fixture(organisation, viewer, :viewer)

      assert {:error, %Ash.Error.Forbidden{}} = create_threat(viewer, organisation, @valid_attrs)
    end

    test "list_threats_of_system and list_threats_of_asset filter in the database" do
      user = AccountsFixtures.user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(user)
      system = SystemsFixtures.system_fixture(user, organisation)
      asset = AssetsFixtures.asset_fixture(user, organisation)

      {:ok, of_system} =
        create_threat(user, organisation, Map.put(@valid_attrs, :system_id, system.id))

      {:ok, of_asset} =
        create_threat(user, organisation, Map.put(@valid_attrs, :asset_id, asset.id))

      {:ok, _other} = create_threat(user, organisation, @valid_attrs)

      assert [%Threat{id: id}] = ThreatManagement.list_threats_of_system!(system.id, actor: user)
      assert id == of_system.id
      assert [%Threat{id: id}] = ThreatManagement.list_threats_of_asset!(asset.id, actor: user)
      assert id == of_asset.id
      assert length(ThreatManagement.list_threats!(organisation.id, actor: user)) == 3
    end
  end

  describe "references of a threat" do
    setup do
      user = AccountsFixtures.user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(user)
      {:ok, threat} = create_threat(user, organisation, @valid_attrs)

      other_user = AccountsFixtures.user_fixture()
      other_organisation = OrganisationsFixtures.organisation_fixture(other_user)

      %{
        user: user,
        organisation: organisation,
        threat: threat,
        other_user: other_user,
        other_organisation: other_organisation
      }
    end

    test "an asset of the same organisation is accepted",
         %{user: user, organisation: organisation, threat: threat} do
      asset = AssetsFixtures.asset_fixture(user, organisation)

      assert {:ok, %Threat{} = updated} =
               ThreatManagement.update_threat(threat, %{asset_id: asset.id}, actor: user)

      assert updated.asset_id == asset.id
    end

    test "an asset of another organisation is rejected", %{
      user: user,
      organisation: organisation,
      threat: threat,
      other_user: other_user,
      other_organisation: other_organisation
    } do
      foreign_asset = AssetsFixtures.asset_fixture(other_user, other_organisation)

      assert {:error, error} =
               create_threat(
                 user,
                 organisation,
                 Map.put(@valid_attrs, :asset_id, foreign_asset.id)
               )

      assert %{asset_id: ["must belong to the same organisation"]} = errors_on(error)

      assert {:error, error} =
               ThreatManagement.update_threat(threat, %{asset_id: foreign_asset.id}, actor: user)

      assert %{asset_id: ["must belong to the same organisation"]} = errors_on(error)

      assert Repo.get!(Threat, threat.id).asset_id == nil
    end

    test "a system of another organisation is rejected, also for a member of both organisations",
         %{
           user: user,
           organisation: organisation,
           threat: threat,
           other_user: other_user,
           other_organisation: other_organisation
         } do
      foreign_system = SystemsFixtures.system_fixture(other_user, other_organisation)
      MembersFixtures.membership_fixture(other_organisation, user, :viewer)

      assert {:error, error} =
               create_threat(
                 user,
                 organisation,
                 Map.put(@valid_attrs, :system_id, foreign_system.id)
               )

      assert %{system_id: ["must belong to the same organisation"]} = errors_on(error)

      assert {:error, error} =
               ThreatManagement.update_threat(threat, %{system_id: foreign_system.id},
                 actor: user
               )

      assert %{system_id: ["must belong to the same organisation"]} = errors_on(error)

      assert Repo.get!(Threat, threat.id).system_id == nil
    end

    test "a threat cannot be created in another organisation",
         %{user: user, other_organisation: other_organisation} do
      assert {:error, %Ash.Error.Forbidden{}} =
               create_threat(user, other_organisation, @valid_attrs)
    end
  end
end
