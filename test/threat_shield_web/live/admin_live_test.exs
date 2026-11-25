defmodule ThreatShieldWeb.AdminLiveTest do
  use ThreatShieldWeb.ConnCase

  import Phoenix.LiveViewTest

  alias ThreatShield.AccountsFixtures
  alias ThreatShield.OrganisationsFixtures
  alias ThreatShield.Repo

  setup %{conn: conn} do
    owner = AccountsFixtures.user_fixture()
    OrganisationsFixtures.organisation_fixture(owner, %{name: "Customer org"})

    admin = AccountsFixtures.user_fixture()

    Repo.query!("UPDATE users SET global_roles = $1 WHERE id = $2", [
      ["platform_admin"],
      admin.id
    ])

    %{conn: conn, admin: admin}
  end

  test "a platform admin sees all organisations", %{conn: conn, admin: admin} do
    {:ok, _view, html} =
      conn |> log_in_user(admin) |> live(~p"/platform-administration/organisations")

    assert html =~ "Customer org"
  end

  test "another user is redirected with a message", %{conn: conn} do
    user = AccountsFixtures.user_fixture()

    assert {:error, {:redirect, %{to: "/", flash: flash}}} =
             conn |> log_in_user(user) |> live(~p"/platform-administration/organisations")

    assert flash["error"] == "You are not allowed to access this page."
  end
end
