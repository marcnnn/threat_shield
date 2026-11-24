defmodule ThreatShieldWeb.AssetLive.AssetsList do
  use ThreatShieldWeb, :live_component

  alias AshThreatShield.ThreatManagement
  alias ThreatShield.Scope
  alias ThreatShieldWeb.AiSuggestions

  alias AshThreatShield.ThreatManagement.System

  import ThreatShieldWeb.Helpers, only: [link_to: 1, system_options: 1]

  require Logger

  attr :ai_suggestions, :map, default: %{}
  attr :scope, :any

  @impl true
  def render(assigns) do
    ~H"""
    <div class="assets" id="assets">
      <div class="mt-4 px-8 py-6 bg-white rounded-lg shadow-sm">
        <.stacked_list_header>
          <:name>
            <span class="text-gray-700 inline-block">
              <Icons.asset_icon class="w-6 h-6" />
            </span>
            {dgettext("assets", "Assets")}
          </:name>

          <:subtitle>
            {dgettext(
              "assets",
              "Asset: short description"
            )}
          </:subtitle>

          <:buttons>
            <.link
              :if={may?(@scope, :create_asset)}
              phx-click="open-create-dialog"
              phx-target={@myself}
            >
              <.button_primary>
                <.icon name="hero-cursor-arrow-ripple" class="mr-1 mb-1" />{dgettext(
                  "assets",
                  "New Asset"
                )}
              </.button_primary>
            </.link>
            <.link>
              <.button_magic
                :if={may?(@scope, :create_asset)}
                phx-click="suggest_assets"
                phx-target={@myself}
              >
                <.icon name="hero-sparkles" class="mr-1 mb-1" />{dgettext(
                  "assets",
                  "Suggest Assets"
                )}
              </.button_magic>
            </.link>
          </:buttons>
        </.stacked_list_header>
        <.stacked_list
          :if={not Enum.empty?(@assets)}
          id={"assets_for_org_#{@scope.organisation.id}"}
          rows={@assets}
          row_click={fn asset -> JS.navigate(link_to(asset)) end}
        >
          <:col :let={asset}>
            {asset.name}
            <p :if={is_list(asset.threats)} class="text-gray-500 text-xs font-normal">
              {asset.threats |> Enum.count()}<span> Threats</span>
            </p>
          </:col>
          <:col :let={asset}>{asset.description}</:col>
          <:col :let={asset}>
            <.criticality_badge
              value={asset.criticality_overall}
              title={dgettext("assets", "Criticality overall")}
            />
          </:col>
          <:col :let={asset}>
            <.criticality_badge
              value={asset.criticality_loss}
              title={dgettext("assets", "Criticality of loss")}
              size_classes="w-8 h-8 leading-7"
            />
          </:col>
          <:col :let={asset}>
            <.criticality_badge
              value={asset.criticality_theft}
              title={dgettext("assets", "Criticality of theft")}
              size_classes="w-8 h-8 leading-7"
            />
          </:col>
          <:col :let={asset}>
            <.criticality_badge
              value={asset.criticality_publication}
              title={dgettext("assets", "Criticality of publication")}
              size_classes="w-8 h-8 leading-7"
            />
          </:col>
        </.stacked_list>

        <p :if={Enum.empty?(@assets)} class="mt-4">
          There are no assets. Please add them manually.
        </p>
      </div>

      <.modal
        :if={assigns[:show_create_dialog] == true}
        id="create-asset-modal"
        show
        on_cancel={JS.navigate(@origin)}
      >
        <.live_component
          module={ThreatShieldWeb.AssetLive.AssetForm}
          id={:new}
          scope={@scope}
          parent_id={@id}
          title={dgettext("assets", "New Asset")}
          action={:new_asset}
          system_options={system_options(@scope.organisation)}
          patch={@origin}
        />
      </.modal>
      <.modal
        :if={assigns[:show_suggest_dialog] == true}
        id="suggest-assets-modal"
        show
        on_cancel={JS.navigate(@origin)}
      >
        <.suggestions_dialog
          title={dgettext("assets", "Suggested Assets")}
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
  def update(%{added_asset: _threat}, socket) do
    socket
    |> assign(:show_create_dialog, false)
    |> ok()
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> load_and_filter_assets(assigns)
    |> ok()
  end

  @impl true
  @spec handle_event(<<_::80, _::_*32>>, any(), atom() | map()) :: {:noreply, any()}
  def handle_event("open-create-dialog", _params, socket) do
    socket
    |> assign(:show_create_dialog, true)
    |> noreply()
  end

  @impl true
  def handle_event("suggest_assets", _params, socket) do
    scope = socket.assigns.scope

    focus = %{system_id: scope.system && scope.system.id}

    socket
    |> AiSuggestions.request(fn ->
      ThreatManagement.suggest_assets(scope.organisation.id, focus, actor: scope.user)
    end)
    |> noreply()
  end

  @impl true
  def handle_event("apply_selection", params, socket) do
    scope = %Scope{} = socket.assigns.scope

    {socket, new_assets} = AiSuggestions.apply_selected(socket, params, &create_asset(scope, &1))

    socket
    |> assign(:assets, socket.assigns.assets ++ new_assets)
    |> noreply()
  end

  @impl true
  def handle_async(:ai_suggestions, result, socket) do
    socket
    |> AiSuggestions.handle_result(result)
    |> noreply()
  end

  # internal

  defp load_and_filter_assets(socket, %{assets: assets}) when is_list(assets) do
    Logger.debug("Assets already provided by caller")
    socket
  end

  defp load_and_filter_assets(socket, %{scope: %Scope{user: user, organisation: org} = scope}) do
    assets =
      case scope do
        %Scope{system: %System{} = system} ->
          ThreatManagement.list_assets_of_system!(system.id, actor: user, load: [:threats])

        _ ->
          ThreatManagement.list_assets!(org.id, actor: user, load: [:threats])
      end

    socket
    |> assign(assets: assets)
  end

  defp create_asset(%Scope{} = scope, %{name: name, description: desc}) do
    ThreatManagement.create_asset(
      %{
        name: name,
        description: desc,
        organisation_id: scope.organisation.id,
        system_id: scope.system && scope.system.id
      },
      actor: scope.user,
      load: [:threats]
    )
  end
end
