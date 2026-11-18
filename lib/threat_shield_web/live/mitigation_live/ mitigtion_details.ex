defmodule ThreatShieldWeb.MitigationLive.MitigationDetails do
  use ThreatShieldWeb, :live_view

  alias ThreatShield.ThreatManagement
  alias ThreatShield.Accounts.Organisation

  import ThreatShieldWeb.Helpers, only: [add_breadcrumbs: 2, get_path_prefix: 1]

  @impl true
  def mount(%{"mitigation_id" => mitigation_id} = _params, _session, socket) do
    user = socket.assigns.current_user
    mitigation = get_mitigation!(user, mitigation_id)

    socket
    |> assign(mitigation: mitigation)
    |> assign(risk: mitigation.risk)
    |> assign(threat: mitigation.risk.threat)
    |> assign(organisation: mitigation.risk.threat.organisation)
    |> assign(
      :membership,
      Organisation.get_membership(mitigation.risk.threat.organisation, user)
    )
    |> assign(system: mitigation.risk.threat.system)
    |> ok()
  end

  @impl true
  def handle_params(_, url, socket) do
    {:noreply,
     socket
     |> add_breadcrumbs(url)
     |> assign(:page_title, page_title(socket.assigns.live_action))}
  end

  @impl true
  def handle_event("delete", %{"mitigation_id" => id}, socket) do
    risk = socket.assigns.risk
    threat = socket.assigns.threat

    case ThreatManagement.destroy_mitigation(id, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         push_navigate(socket,
           to: get_path_prefix(socket.assigns) <> "/threats/#{threat.id}/risks/#{risk.id}"
         )}

      {:error, _error} ->
        socket
        |> put_flash(:error, dgettext("mitigations", "The mitigation could not be deleted."))
        |> noreply()
    end
  end

  @impl true
  def handle_info(
        {ThreatShieldWeb.MitigationLive.MitigationForm, {:saved, mitigation}},
        socket
      ) do
    mitigation = get_mitigation!(socket.assigns.current_user, mitigation.id)

    {:noreply,
     socket
     |> assign(mitigation: mitigation)
     |> assign(page_title: "Show Mitigation")}
  end

  defp get_mitigation!(user, id) do
    ThreatManagement.get_mitigation!(id,
      actor: user,
      load: [risk: [threat: [:system, organisation: [:memberships]]]]
    )
  end

  defp page_title(:show), do: "Show Mitigation"
  defp page_title(:edit_mitigation), do: "Edit Mitigation"
end
