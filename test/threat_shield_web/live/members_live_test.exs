defmodule ThreatShieldWeb.MembersLiveTest do
  use ThreatShieldWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias ThreatShield.Accounts.Invite
  alias ThreatShield.AccountsFixtures
  alias ThreatShield.MembersFixtures
  alias ThreatShield.OrganisationsFixtures
  alias ThreatShield.Repo

  # The create action of the LiveView process sends the email; in global mode it goes
  # only to the test process
  setup [:register_and_log_in_user, :set_swoosh_global]

  test "an invite sends the link to join the organisation", %{conn: conn, user: user} do
    organisation = OrganisationsFixtures.organisation_fixture(user, %{name: "ACME"})

    {:ok, view, _html} = live(conn, ~p"/organisations/#{organisation.id}/members/new")

    view
    |> form("#invite-form", invite: %{email: "invited@example.com"})
    |> render_submit()

    render(view)

    %Invite{token: token} = Repo.get_by!(Invite, email: "invited@example.com")

    assert_email_sent(fn email ->
      assert email.to == [{"", "invited@example.com"}]
      assert email.text_body =~ url(~p"/join/#{token}")
    end)
  end

  test "an existing member cannot be invited", %{conn: conn, user: user} do
    organisation = OrganisationsFixtures.organisation_fixture(user, %{name: "ACME"})
    member = AccountsFixtures.confirmed_user_fixture()
    MembersFixtures.membership_fixture(organisation, member, :viewer)

    {:ok, view, _html} = live(conn, ~p"/organisations/#{organisation.id}/members/new")

    html =
      view
      |> form("#invite-form", invite: %{email: String.upcase(to_string(member.email))})
      |> render_submit()

    assert html =~ "is already a member of this organisation"
    refute Repo.get_by(Invite, organisation_id: organisation.id)
  end

  test "the members page does not list expired invites", %{conn: conn, user: user} do
    organisation = OrganisationsFixtures.organisation_fixture(user, %{name: "ACME"})
    MembersFixtures.invite_fixture(user, organisation, "open@example.com")
    expired = MembersFixtures.invite_fixture(user, organisation, "expired@example.com")

    old = DateTime.add(DateTime.utc_now(), -40, :day)

    Repo.query!("UPDATE invites SET inserted_at = $1 WHERE id = $2", [
      DateTime.to_naive(old),
      expired.id
    ])

    {:ok, _view, html} = live(conn, ~p"/organisations/#{organisation.id}/members")

    assert html =~ "open@example.com"
    refute html =~ "expired@example.com"
  end

  test "a viewer who submits an invite gets a message", %{conn: conn, user: user} do
    owner = AccountsFixtures.user_fixture()
    organisation = OrganisationsFixtures.organisation_fixture(owner, %{name: "ACME"})
    MembersFixtures.membership_fixture(organisation, user, :viewer)

    {:ok, view, _html} = live(conn, ~p"/organisations/#{organisation.id}/members/new")

    view
    |> form("#invite-form", invite: %{email: "someone@example.com"})
    |> render_submit()

    assert_patch(view, ~p"/organisations/#{organisation.id}/members")
    assert render(view) =~ "You are not allowed to do this."
    refute Repo.get_by(Invite, email: "someone@example.com")
  end
end
