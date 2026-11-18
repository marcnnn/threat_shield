defmodule ThreatShieldWeb.WelcomeController do
  use ThreatShieldWeb, :controller

  alias ThreatShield.Accounts

  def home(conn, _params) do
    case Accounts.list_organisations!(actor: conn.assigns.current_user) do
      [single_org] ->
        conn
        |> redirect(to: ~p"/organisations/#{single_org.id}")

      _else ->
        conn
        |> redirect(to: ~p"/organisations")
    end
  end
end
