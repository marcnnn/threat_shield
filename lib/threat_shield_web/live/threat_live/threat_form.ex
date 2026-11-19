defmodule ThreatShieldWeb.ThreatLive.ThreatForm do
  use ThreatShieldWeb, :live_component

  import ThreatShieldWeb.FormHelpers

  alias ThreatShield.Scope
  alias AshThreatShield.ThreatManagement.Threat

  use Gettext, backend: ThreatShieldWeb.Gettext

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl">
      <.header>
        <%= @title %>
      </.header>

      <p class="help-text">
        <%= dgettext(
          "threats",
          "Threat: long description"
        ) %>
      </p>

      <.simple_form
        for={@form}
        id="threat-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label={dgettext("threats", "Name")} required />
        <.input
          field={@form[:description]}
          type="text"
          label={dgettext("threats", "Description")}
          required
        />
        <.input
          :if={assigns[:system_options]}
          field={@form[:system_id]}
          type="select"
          label="System"
          options={@system_options}
        />
        <.input
          :if={assigns[:asset_options]}
          field={@form[:asset_id]}
          type="select"
          label="Asset"
          options={@asset_options}
        />
        <:actions>
          <.button_primary phx-disable-with={dgettext("common", "Saving...")} class="mt-2">
            <%= dgettext("threats", "Save Threat") %>
          </.button_primary>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_form(build_form(assigns))
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"threat" => threat_params}, socket) do
    {:noreply, validate_form(socket, threat_params)}
  end

  def handle_event("save", %{"threat" => threat_params}, socket) do
    save_threat(socket, socket.assigns.action, threat_params)
  end

  defp build_form(%{action: :edit_threat, threat: threat, scope: %Scope{user: user}}) do
    AshPhoenix.Form.for_update(threat, :update, actor: user, as: "threat")
  end

  defp build_form(%{action: :new_threat, scope: %Scope{user: user, organisation: org} = scope}) do
    AshPhoenix.Form.for_create(Threat, :create,
      actor: user,
      as: "threat",
      params: %{
        "system_id" => scope.system && scope.system.id,
        "asset_id" => scope.asset && scope.asset.id
      },
      # the threat belongs to the organisation of the page, whatever the client sends
      transform_params: fn params, _type -> Map.put(params, "organisation_id", org.id) end
    )
  end

  defp save_threat(socket, :edit_threat, threat_params) do
    {socket, _result} =
      submit_form(socket, threat_params, __MODULE__, "Threat updated successfully")

    noreply(socket)
  end

  defp save_threat(socket, :new_threat, threat_params) do
    {socket, result} =
      submit_form(socket, threat_params, __MODULE__, "Threat created successfully",
        load: [:system, :asset]
      )

    with {:ok, threat} <- result do
      notify_threat_list(id: socket.assigns.parent_id, added_threat: threat)
    end

    noreply(socket)
  end

  defp notify_threat_list(msg),
    do: send_update(self(), ThreatShieldWeb.ThreatLive.ThreatsList, msg)
end
