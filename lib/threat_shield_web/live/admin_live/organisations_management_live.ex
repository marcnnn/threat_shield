defmodule ThreatShieldWeb.AdminLive.OrganisationsManagement do
  use ThreatShieldWeb, :live_view

  alias ThreatShield.Accounts
  alias ThreatShieldWeb.Locations

  import ThreatShield.Accounts.Organisation, only: [attributes_config: 0]

  @impl true
  def mount(_params, _session, socket) do
    locations_options = Locations.list_locations()

    organisations = Accounts.list_organisations!(actor: socket.assigns.current_user)

    socket
    |> assign(locations_options: locations_options)
    |> stream_organisations(organisations)
    |> assign(:attributes, attributes_config())
    |> ok()
  end

  defp stream_organisations(socket, organisations) do
    stream(
      socket,
      :organisations,
      organisations
    )
  end
end
