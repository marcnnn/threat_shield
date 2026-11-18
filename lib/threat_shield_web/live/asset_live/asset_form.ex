defmodule ThreatShieldWeb.AssetLive.AssetForm do
  use ThreatShieldWeb, :live_component

  import ThreatShieldWeb.FormHelpers

  alias ThreatShield.Scope
  alias ThreatShield.ThreatManagement.Asset

  import ThreatShieldWeb.TsComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
      </.header>
      <p>
        <%= dgettext(
          "assets",
          "Asset: long description"
        ) %>
      </p>

      <.simple_form
        for={@form}
        id="asset-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" required />
        <.input field={@form[:description]} type="textarea" label="Description" required />
        <.input
          :if={assigns[:system_options]}
          field={@form[:system_id]}
          type="select"
          label="System"
          options={@system_options}
        />
        <hr />
        <div class="lg:grid grid-flow-col justify-stretch space-x-4">
          <.criticality_picker
            field={@form[:criticality_loss]}
            label={dgettext("assets", "Criticality of loss")}
          />
          <.criticality_picker
            field={@form[:criticality_theft]}
            label={dgettext("assets", "Criticality of theft")}
          />
          <.criticality_picker
            field={@form[:criticality_publication]}
            label={dgettext("assets", "Criticality of publication")}
          />
        </div>
        <div class="py-5">
          <.criticality_picker
            field={@form[:criticality_overall]}
            label={dgettext("assets", "Criticality overall")}
          />
        </div>
        <:actions>
          <.button_primary phx-disable-with="Saving...">Save Asset</.button_primary>
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
  def handle_event("validate", %{"asset" => asset_params}, socket) do
    {:noreply, validate_form(socket, asset_params)}
  end

  def handle_event("save", %{"asset" => asset_params}, socket) do
    save_asset(socket, socket.assigns.action, asset_params)
  end

  defp build_form(%{action: :edit, asset: asset, scope: %Scope{user: user}}) do
    AshPhoenix.Form.for_update(asset, :update, actor: user, as: "asset")
  end

  defp build_form(%{action: :new_asset, scope: %Scope{user: user, organisation: org} = scope}) do
    AshPhoenix.Form.for_create(Asset, :create,
      actor: user,
      as: "asset",
      params: %{
        "system_id" => scope.system && scope.system.id,
        "criticality_loss" => 0.0,
        "criticality_theft" => 0.0,
        "criticality_publication" => 0.0,
        "criticality_overall" => 0.0
      },
      # the asset belongs to the organisation of the page, whatever the client sends
      transform_params: fn params, _type -> Map.put(params, "organisation_id", org.id) end
    )
  end

  defp save_asset(socket, :edit, asset_params) do
    {socket, _result} =
      submit_form(socket, asset_params, __MODULE__, "Asset updated successfully")

    noreply(socket)
  end

  defp save_asset(socket, :new_asset, asset_params) do
    {socket, result} =
      submit_form(socket, asset_params, __MODULE__, "Asset created successfully", load: [:system])

    with {:ok, asset} <- result do
      notify_asset_list(id: socket.assigns.parent_id, added_asset: asset)
    end

    noreply(socket)
  end

  defp notify_asset_list(msg),
    do: send_update(self(), ThreatShieldWeb.AssetLive.AssetsList, msg)
end
