defmodule ThreatShieldWeb.AssetLive.AssetDetails do
  use ThreatShieldWeb, :live_view

  alias AshThreatShield.ThreatManagement
  alias AshThreatShield.ThreatManagement.Asset

  import ThreatShieldWeb.ScopeUrlBinding

  import ThreatShieldWeb.Helpers,
    only: [add_breadcrumbs: 2, get_path_prefix: 1, system_options: 1, asset_options: 1]

  import ThreatShieldWeb.Labels, only: [system_label: 1]

  @impl true
  def mount(%{"asset_id" => asset_id} = params, _session, socket) do
    current_user = socket.assigns.current_user
    asset = get_asset!(current_user, asset_id)
    threats = asset.threats

    scope = asset_scope_from_params(current_user, asset, params)

    socket
    |> assign(scope: scope)
    |> assign(asset: asset)
    |> assign(threats: threats)
    |> assign(organisation: asset.organisation)
    |> assign(system: asset.system)
    |> assign(system_options: system_options(asset.organisation))
    |> assign(asset_options: asset_options(asset.organisation))
    |> assign(origin: asset_scope_to_url(scope))
    |> ok()
  end

  @impl true
  def handle_params(_params, url, socket) do
    socket
    |> add_breadcrumbs(url)
    |> assign(page_title: page_title(socket.assigns.live_action))
    |> noreply()
  end

  @impl true
  def handle_event("delete", %{"asset_id" => asset_id}, socket) do
    case ThreatManagement.destroy_asset(asset_id, actor: socket.assigns.current_user) do
      :ok ->
        socket
        |> push_navigate(to: get_path_prefix(socket.assigns))
        |> noreply()

      {:error, _error} ->
        socket
        |> put_flash(:error, dgettext("assets", "The asset could not be deleted."))
        |> noreply()
    end
  end

  @impl true
  def handle_info({ThreatShieldWeb.ThreatLive.ThreatForm, {:saved, threat}}, socket) do
    stale_asset = %Asset{} = socket.assigns.asset

    socket
    |> assign(asset: %Asset{stale_asset | threats: stale_asset.threats ++ [threat]})
    |> noreply()
  end

  @impl true
  def handle_info(
        {ThreatShieldWeb.AssetLive.AssetForm, {:saved, asset}},
        socket
      ) do
    asset = get_asset!(socket.assigns.current_user, asset.id)

    socket
    |> assign(asset: asset)
    |> assign(organisation: asset.organisation)
    |> assign(system: asset.system)
    |> assign(page_title: "Show Asset")
    |> noreply()
  end

  defp get_asset!(user, id) do
    ThreatManagement.get_asset!(id,
      actor: user,
      load: [
        :system,
        threats: [:system, :asset],
        organisation: [:systems, :assets, :actor_membership]
      ]
    )
  end

  defp page_title(:show), do: "Show Asset"
  defp page_title(:edit), do: "Edit Asset"
end
