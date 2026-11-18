defmodule ThreatShieldWeb.SystemLive.SystemDetails do
  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.Organisation
  alias ThreatShield.Accounts.User
  use ThreatShieldWeb, :live_view

  alias ThreatShield.Scope
  alias ThreatShield.ThreatManagement
  alias ThreatShield.ThreatManagement.System
  import ThreatShieldWeb.Helpers, only: [add_breadcrumbs: 2, link_to: 1]

  @impl true
  def mount(%{"sys_id" => id}, _session, socket) do
    %User{} = user = socket.assigns.current_user
    %System{} = system = get_system!(user, id)
    %Organisation{} = organisation = get_organisation!(user, system.organisation_id)

    socket
    |> assign(:current_tab, :assets)
    |> assign(:system, system)
    |> assign(:organisation, organisation)
    |> assign(:membership, Organisation.get_membership(organisation, user))
    |> assign(:attributes, System.attributes_config())
    |> assign(:scope, Scope.for_system(user, organisation, system))
    |> ok()
  end

  @impl true
  def handle_params(params, url, socket) do
    socket
    |> add_breadcrumbs(url)
    |> apply_action(socket.assigns.live_action, params)
    |> noreply()
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "Show System")
  end

  defp apply_action(socket, :edit_system, _params) do
    socket
    |> assign(:page_title, "Edit System")
  end

  # events and notifications

  @impl true
  def handle_info(
        {ThreatShieldWeb.SystemLive.SystemForm, {:saved, system}},
        socket
      ) do
    user = socket.assigns.current_user
    system = get_system!(user, system.id)

    {:noreply,
     socket
     |> assign(system: system)
     |> assign(organisation: system.organisation)
     |> assign(page_title: "Show System")}
  end

  @impl true
  def handle_info({ThreatShieldWeb.AssetLive.AssetForm, {:saved, asset}}, socket) do
    stale_sys = socket.assigns.system
    updated_sys = %{stale_sys | assets: stale_sys.assets ++ [asset]}

    {:noreply, socket |> assign(system: updated_sys) |> assign(page_title: "Show System")}
  end

  @impl true
  def handle_info({ThreatShieldWeb.ThreatLive.ThreatForm, {:saved, threat}}, socket) do
    stale_sys = socket.assigns.system
    updated_sys = %{stale_sys | threats: stale_sys.threats ++ [threat]}

    {:noreply, socket |> assign(system: updated_sys) |> assign(page_title: "Show System")}
  end

  @impl true
  def handle_event("delete", %{"sys_id" => id}, socket) do
    case ThreatManagement.destroy_system(id, actor: socket.assigns.current_user) do
      :ok ->
        socket
        |> push_navigate(to: ~p"/organisations/#{socket.assigns.organisation.id}")
        |> noreply()

      {:error, _error} ->
        socket
        |> put_flash(:error, dgettext("systems", "The system could not be deleted."))
        |> noreply()
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    socket
    |> assign(current_tab: String.to_existing_atom(tab))
    |> noreply()
  end

  defp get_system!(user, id) do
    ThreatManagement.get_system!(id,
      actor: user,
      load: [:assets, :threats, organisation: [:systems, :memberships]]
    )
  end

  defp get_organisation!(user, id) do
    Accounts.get_organisation!(id,
      actor: user,
      load: [:memberships, :systems, assets: [:system], threats: [:system, :asset]]
    )
  end
end
