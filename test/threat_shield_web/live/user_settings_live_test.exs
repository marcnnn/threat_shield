defmodule ThreatShieldWeb.UserSettingsLiveTest do
  use ThreatShieldWeb.ConnCase

  alias ThreatShield.Accounts
  import Phoenix.LiveViewTest
  import ThreatShield.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})
      %{conn: log_in_user(conn, user), user: user, password: password}
    end

    test "updates the user email", %{conn: conn, password: password, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_user_by_email!(user.email, authorize?: false)

      assert_received {:email, %{to: [{_, ^new_email}], text_body: body}}
      assert body =~ "/users/settings/confirm_email/"
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})
      %{conn: log_in_user(conn, user), user: user, password: password}
    end

    test "updates the user password", %{conn: conn, user: user, password: password} do
      new_password = valid_user_password()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/users/settings"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert {:ok, _} = Accounts.sign_in_user(user.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn ->
          Accounts.change_user_email(user, email, valid_user_password(), actor: user)
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_user_by_email!(user.email, authorize?: false)
      assert Accounts.get_user_by_email!(email, authorize?: false)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_user_by_email!(user.email, authorize?: false)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end

  describe "API keys" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "creates a key, shows it once, and the key signs in",
         %{conn: conn, user: %{id: user_id} = user} do
      {:ok, lv, html} = live(conn, ~p"/users/settings")
      assert html =~ "http://localhost:4002/mcp"
      refute html =~ "new_api_key"

      html = lv |> form("#api_key_form", api_key: %{valid_for_days: "30"}) |> render_submit()

      [_, key] = Regex.run(~r{<code[^>]*>(threatshield_[^<]+)</code>}, html)
      assert {:ok, %{id: ^user_id}} = Accounts.sign_in_with_api_key(key)

      assert [api_key] = Accounts.list_api_keys!(actor: user)
      days = DateTime.diff(api_key.expires_at, DateTime.utc_now(), :day)
      assert days in 29..30
      assert has_element?(lv, "#api_key-#{api_key.id}")

      # the key is not shown again
      {:ok, _lv, html} = live(conn, ~p"/users/settings")
      refute html =~ key
    end

    test "revokes a key", %{conn: conn, user: user} do
      key = api_key_fixture(user)
      [api_key] = Accounts.list_api_keys!(actor: user)

      {:ok, lv, _html} = live(conn, ~p"/users/settings")
      lv |> element("#api_key-#{api_key.id} button", "Revoke") |> render_click()

      refute has_element?(lv, "#api_key-#{api_key.id}")
      assert [] = Accounts.list_api_keys!(actor: user)
      assert {:error, _} = Accounts.sign_in_with_api_key(key)
    end

    test "does not revoke the key of another user", %{conn: conn} do
      other = user_fixture()
      key = api_key_fixture(other)
      [api_key] = Accounts.list_api_keys!(actor: other)

      {:ok, lv, _html} = live(conn, ~p"/users/settings")
      assert render_click(lv, "revoke_api_key", %{"id" => api_key.id}) =~ "was not found"

      assert {:ok, _} = Accounts.sign_in_with_api_key(key)
    end
  end
end
