defmodule ThreatShieldWeb.UserAuth do
  use ThreatShieldWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Phoenix.LiveView.Socket
  alias ThreatShield.Accounts.Helpers, as: Accounts

  # Make the remember me cookie valid for 60 days.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_threat_shield_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax", http_only: true]

  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
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

  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      ThreatShieldWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
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
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session["user_token"] do
        Accounts.get_user_by_session_token(user_token)
      end
    end)
  end

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

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
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
