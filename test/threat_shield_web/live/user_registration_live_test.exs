defmodule ThreatShieldWeb.UserRegistrationLiveTest do
  use ThreatShieldWeb.ConnCase

  import Phoenix.LiveViewTest
  import ThreatShield.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Sign up"
      assert html =~ "Sign in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, "/organisations")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "too short"})

      assert result =~ "Sign up"
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 12 character"
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      form =
        form(lv, "#registration_form",
          user: %{
            "email" => email,
            "password" => valid_user_password(),
            "first_name" => "Test",
            "last_name" => "User",
            "accept_toc" => "true"
          }
        )

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      conn = get(conn, "/organisations")
      response = html_response(conn, 200)
      assert response =~ "Account settings"
      assert response =~ "Log out"
    end

    test "joins the organisation of the invite link", %{conn: conn} do
      owner = user_fixture()
      organisation = ThreatShield.OrganisationsFixtures.organisation_fixture(owner)
      email = unique_user_email()
      invite = ThreatShield.MembersFixtures.invite_fixture(owner, organisation, email)

      {:ok, lv, html} = live(conn, ~p"/users/register?token=#{invite.token}")
      assert html =~ email

      lv
      |> form("#registration_form",
        user: %{
          "email" => email,
          "password" => valid_user_password(),
          "first_name" => "Test",
          "last_name" => "User",
          "accept_toc" => "true"
        }
      )
      |> render_submit()

      user = ThreatShield.Accounts.get_user_by_email!(email, authorize?: false)
      organisation_id = organisation.id

      assert [%{id: ^organisation_id}] =
               ThreatShield.Accounts.list_organisations!(actor: user)
    end

    test "rejects an unknown invite token", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/users/register", flash: flash}}} =
               live(conn, ~p"/users/register?token=unknown")

      assert flash["error"] =~ "Invalid invitation token"
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => to_string(user.email), "password" => "valid_password12"}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Sign in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Sign in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert login_html =~ "Sign in"
    end
  end
end
