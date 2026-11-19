defmodule ThreatShieldWeb.ThreatLive.ThreatsList do
  use ThreatShieldWeb, :live_component

  alias ThreatShield.Scope
  alias ThreatShieldWeb.AiSuggestions

  alias AshThreatShield.ThreatManagement
  alias AshThreatShield.ThreatManagement.System

  import ThreatShieldWeb.Labels
  import ThreatShieldWeb.Helpers

  require Logger

  @load [:system, :asset, :risks]

  @moduledoc """
  This component renders a list of threats for a given system or for the organization.
  It also provides a button to create a new threat in a modal dialog.
  This component is designed to be used in different contexts,
  e.g. to list and add threats for organisations, systems, and assets.
  """

  @impl true
  def render(%{id: _component_id} = assigns) do
    ~H"""
    <div class="threats">
      <div class="mt-4 px-8 py-6 bg-white rounded-lg shadow">
        <.stacked_list_header>
          <:name>
            <span class="text-gray-800 inline-block">
              <Icons.threat_icon class="w-6 h-6" />
            </span>
            <%= dgettext("threats", "Threats") %>
          </:name>

          <:subtitle>
            <%= dgettext("threats", "Threat: short description") %>
          </:subtitle>

          <:buttons>
            <.link
              :if={may?(@scope, :create_threat)}
              phx-click="open-create-dialog"
              phx-target={@myself}
            >
              <.button_primary>
                <.icon name="hero-cursor-arrow-ripple" class="mr-1 mb-1" /><%= dgettext(
                  "threats",
                  "New Threat"
                ) %>
              </.button_primary>
            </.link>
            <.link>
              <.button_magic
                :if={may?(@scope, :create_threat)}
                phx-click="suggest_threats"
                phx-target={@myself}
              >
                <.icon name="hero-sparkles" class="mr-1 mb-1" /><%= dgettext(
                  "threats",
                  "Suggest Threats"
                ) %>
              </.button_magic>
            </.link>
          </:buttons>
        </.stacked_list_header>
        <.stacked_list
          :if={not Enum.empty?(@threats)}
          id={"threats_for_#{@scope.id}"}
          rows={@threats}
          row_click={fn threat -> JS.navigate(link_to(threat)) end}
        >
          <:col :let={threat}>
            <%= threat.name %>
          </:col>
          <:col :let={threat}>
            <%= system_label(threat) %>
          </:col>
          <:col :let={threat}>
            <%= asset_label(threat) %>
          </:col>
          <:col :let={threat}><%= threat.description %></:col>
        </.stacked_list>

        <p :if={Enum.empty?(@threats)} class="mt-4">
          There are no threats. Please add them manually or let the AI assistant make some suggestions.
        </p>
      </div>

      <.modal
        :if={assigns[:show_create_dialog] == true}
        id="create-threat-modal"
        show
        on_cancel={JS.navigate(@origin)}
      >
        <.live_component
          module={ThreatShieldWeb.ThreatLive.ThreatForm}
          id={:new}
          parent_id={@id}
          action={:new_threat}
          title={dgettext("threats", "New Threat")}
          scope={@scope}
          system_options={system_options(@scope.organisation)}
          asset_options={asset_options(@scope.organisation)}
          patch={@origin}
        />
      </.modal>
      <.modal
        :if={assigns[:show_suggest_dialog] == true}
        id="suggest-threats-modal"
        show
        on_cancel={JS.navigate(@origin)}
      >
        <.suggestions_dialog
          title={dgettext("threats", "Suggested Threats")}
          listener={@myself}
          scope={@scope}
          suggestions={assigns[:ai_suggestions]}
        />
      </.modal>
    </div>
    """
  end

  # events

  @impl true
  def update(%{added_threat: threat}, socket) do
    old_threats = socket.assigns[:threats] || []

    # reload to resolve associations
    threat = get_threat!(socket.assigns.scope.user, threat.id)

    socket
    |> assign(:show_create_dialog, false)
    |> assign(:threats, old_threats ++ [threat])
    |> ok()
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> load_and_filter_threats(assigns)
    |> ok()
  end

  @impl true
  def handle_event("open-create-dialog", _params, socket) do
    socket
    |> assign(:show_create_dialog, true)
    |> noreply()
  end

  @impl true
  def handle_event("suggest_threats", _params, socket) do
    scope = socket.assigns.scope

    focus = %{system_id: scope.system && scope.system.id, asset_id: scope.asset && scope.asset.id}

    socket
    |> AiSuggestions.request(fn ->
      ThreatManagement.suggest_threats(scope.organisation.id, focus, actor: scope.user)
    end)
    |> noreply()
  end

  @impl true
  def handle_event("apply_selection", params, socket) do
    scope = %Scope{} = socket.assigns.scope

    new_threats =
      socket
      |> AiSuggestions.selected(params)
      |> Enum.map(fn s -> create_threat(scope, s) end)

    socket
    |> assign(:show_suggest_dialog, false)
    |> assign(:threats, socket.assigns.threats ++ new_threats)
    |> noreply()
  end

  @impl true
  def handle_async(:ai_suggestions, result, socket) do
    socket
    |> AiSuggestions.handle_result(result)
    |> noreply()
  end

  # internal

  defp load_and_filter_threats(socket, %{threats: threats}) when is_list(threats) do
    Logger.debug("Threats already provided by caller")
    socket
  end

  defp load_and_filter_threats(socket, %{scope: %Scope{user: user, organisation: org} = scope}) do
    threats =
      case scope do
        %Scope{system: %System{} = system} ->
          ThreatManagement.list_threats_of_system!(system.id, actor: user, load: @load)

        _ ->
          ThreatManagement.list_threats!(org.id, actor: user, load: @load)
      end

    socket
    |> assign(threats: threats)
  end

  defp create_threat(%Scope{} = scope, %{name: name, description: desc}) do
    ThreatManagement.create_threat!(
      %{
        name: name,
        description: desc,
        organisation_id: scope.organisation.id,
        system_id: scope.system && scope.system.id,
        asset_id: scope.asset && scope.asset.id
      },
      actor: scope.user,
      load: @load
    )
  end

  defp get_threat!(user, id), do: ThreatManagement.get_threat!(id, actor: user, load: @load)
end
