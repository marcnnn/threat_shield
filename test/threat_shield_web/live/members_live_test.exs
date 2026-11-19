defmodule ThreatShieldWeb.MembersLiveTest do
  use ThreatShieldWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias ThreatShield.Accounts.Invite
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
end
