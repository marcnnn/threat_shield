defmodule ThreatShieldWeb.UserAuth do
  @moduledoc """
  Sessions of the browser, based on the tokens of AshAuthentication.

  A session holds a token of `ThreatShield.Accounts.Token` under `"user_token"`. The
  token authenticates only while it is stored and not revoked, so signing out ends
  the session, also for the "remember me" cookie, which holds the same token.
  """

  use ThreatShieldWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Phoenix.LiveView.Socket
  alias ThreatShield.Accounts.Senders.Urls
  alias ThreatShield.Accounts.User

  @otp_app :threat_shield

  # Valid as long as the token, see the token lifetime of `ThreatShield.Accounts.User`
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_threat_shield_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax", http_only: true]

  @doc """
  The action context with the URL builders for the links in the account emails. Pass
  it to the actions that send emails, see `ThreatShield.Accounts.Senders.Urls`.
  """
  def account_urls_context do
    Urls.context(%{
      confirm: &url(~p"/users/confirm/#{&1}"),
      reset_password: &url(~p"/users/reset_password/#{&1}"),
      confirm_email_change: &url(~p"/users/settings/confirm_email/#{&1}")
    })
  end

  @doc """
  Logs the user in. The user comes from a sign in action and carries its token in
  the metadata.

  It renews the session ID and clears the whole session to avoid fixation attacks.
  """
  def log_in_user(conn, %User{__metadata__: %{token: token}} = user, params \\ %{})
      when is_binary(token) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> AuthHelpers.store_in_session(user)
    |> put_live_socket_id(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out. Revokes the token of the session, which also invalidates the
  "remember me" cookie, and disconnects the LiveViews of the session.
  """
  def log_out_user(conn) do
    conn = AuthHelpers.revoke_session_tokens(conn, @otp_app)

    if live_socket_id = get_session(conn, :live_socket_id) do
      ThreatShieldWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by the token in the session or in the "remember me" cookie
  and assigns it, with its organisations, as `:current_user`.
  """
  def fetch_current_user(conn, _opts) do
    conn =
      conn
      |> ensure_user_token()
      |> AuthHelpers.retrieve_from_session(@otp_app)

    assign(conn, :current_user, with_organisations(conn.assigns.current_user))
  end

  defp ensure_user_token(conn) do
    if get_session(conn, :user_token) do
      conn
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        conn
        |> put_session(:user_token, token)
        |> put_live_socket_id(token)
      else
        conn
      end
    end
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> unauthenticated_flash()
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  def on_mount(:ensure_platform_admin, _params, session, socket) do
    socket = mount_current_user(socket, session)
    current_user = socket.assigns.current_user

    if current_user && "platform_admin" in (current_user.global_roles || []) do
      {:cont, socket}
    else
      socket =
        socket
        |> flash("You are not allowed to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  defp mount_current_user(socket, session) do
    socket
    |> AuthHelpers.assign_new_resources(session, &Phoenix.Component.assign_new/3,
      otp_app: @otp_app
    )
    |> Phoenix.Component.update(:current_user, &with_organisations/1)
  end

  defp with_organisations(%User{organisations: %Ash.NotLoaded{}} = user) do
    case Ash.load(user, :organisations, actor: user) do
      {:ok, user} -> user
      {:error, _} -> user
    end
  end

  defp with_organisations(user), do: user

  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> unauthenticated_flash()
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  defp put_live_socket_id(conn, token) do
    put_session(conn, :live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/organisations"

  defp unauthenticated_flash(%Socket{} = socket) do
    flash(socket, "You must log in to access this page.")
  end

  defp unauthenticated_flash(%Plug.Conn{} = conn) do
    flash(conn, "You must log in to access this page.")
  end

  defp flash(%Socket{} = socket, message) do
    if is_nil(socket.router) or unauth_flash_needed(socket.router.assigns[:path_info]) do
      socket
      |> Phoenix.LiveView.put_flash(:error, message)
    else
      socket
    end
  end

  defp flash(%Plug.Conn{} = conn, message) do
    if unauth_flash_needed(conn.request_path) do
      conn
      |> put_flash(:error, message)
    else
      conn
    end
  end

  defp unauth_flash_needed(url) do
    case url do
      "/users/log_in" -> false
      "/users/sign_up" -> false
      "/organisations" -> false
      "/" -> false
      _ -> true
    end
  end
end
