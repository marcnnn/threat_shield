defmodule ThreatShieldWeb.SystemLive.SystemForm do
  use ThreatShieldWeb, :live_component

  import ThreatShieldWeb.FormHelpers

  alias AshThreatShield.DynamicAttribute
  alias AshThreatShield.ThreatManagement.System

  import AshThreatShield.ThreatManagement.System, only: [attributes_config: 0]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
      </.header>

      <p class="help-text">
        {dgettext("systems", "System: long description")}
      </p>

      <.simple_form
        for={@form}
        id="system-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="text" label="Description" />
        <em>
          {dgettext(
            "common",
            "The more details you provide about context and purpose of this system, the better the suggestions can be."
          )}
        </em>
        <%= for attribute <- @attributes do %>
          <.input
            name={attribute.name}
            value={Map.get(@attribute_map, attribute.name, "")}
            type="text"
            label={attribute.name}
          />
          <em>e.g. {DynamicAttribute.get_suggestions(attribute) |> Enum.join(", ")}</em>
        <% end %>
        <:actions>
          <.button_primary phx-disable-with="Saving...">Save System</.button_primary>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{system: system} = assigns, socket) do
    attribute_map = system.attributes || %{}

    socket
    |> assign(assigns)
    |> assign_form(build_form(assigns))
    |> assign(:attribute_map, attribute_map)
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"system" => system_params}, socket) do
    {:noreply, validate_form(socket, system_params)}
  end

  def handle_event("save", %{"system" => system_params} = params, socket) do
    attributes = extract_attributes_from_params(params)
    save_system(socket, socket.assigns.action, Map.put(system_params, "attributes", attributes))
  end

  defp build_form(%{action: :edit_system, system: system, current_user: user}) do
    AshPhoenix.Form.for_update(system, :update, actor: user, as: "system")
  end

  defp build_form(%{action: :new_system, organisation: organisation, current_user: user}) do
    AshPhoenix.Form.for_create(System, :create,
      actor: user,
      as: "system",
      # the system belongs to the organisation of the page, whatever the client sends
      transform_params: fn params, _type ->
        Map.put(params, "organisation_id", organisation.id)
      end
    )
  end

  defp extract_attributes_from_params(params) do
    attributes_config()
    |> Enum.map(fn d -> {d.name, Map.get(params, d.name, "")} end)
    |> Map.new()
  end

  defp save_system(socket, :edit_system, system_params) do
    {socket, _result} =
      submit_form(socket, system_params, __MODULE__, "System updated successfully")

    noreply(socket)
  end

  defp save_system(socket, :new_system, system_params) do
    {socket, result} =
      submit_form(socket, system_params, __MODULE__, "System created successfully")

    with {:ok, system} <- result do
      notify_systems_list(id: socket.assigns.parent_id, added_system: system)
    end

    noreply(socket)
  end

  defp notify_systems_list(msg),
    do: send_update(self(), ThreatShieldWeb.SystemLive.SystemsList, msg)
end
