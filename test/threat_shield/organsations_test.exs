defmodule ThreatShield.OrganisationsTest do
  use ThreatShield.DataCase

  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.Organisation
  alias ThreatShield.AccountsFixtures
  alias ThreatShield.OrganisationsFixtures

  describe "organisations" do
    test "create_organisation with valid data creates an organisation" do
      user = AccountsFixtures.user_fixture()

      assert {:ok, %Organisation{} = organisation} =
               Accounts.create_organisation(%{name: "some name"}, actor: user)

      assert organisation.attributes == %{}
    end

    test "create_organisation with invalid data returns error" do
      user = AccountsFixtures.user_fixture()

      assert {:error, _} = Accounts.create_organisation(%{}, actor: user)
    end

    test "create_organisation needs an actor" do
      assert {:error, _} = Accounts.create_organisation(%{name: "x"})
      refute ThreatShield.Repo.get_by(Organisation, name: "x")
    end

    test "update_organisation with valid data updates the organisation" do
      user = AccountsFixtures.user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(user)

      assert {:ok, %Organisation{name: "Updated Name"}} =
               Accounts.update_organisation(organisation, %{name: "Updated Name"}, actor: user)
    end
  end
end
