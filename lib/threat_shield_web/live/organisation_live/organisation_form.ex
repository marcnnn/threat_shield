defmodule ThreatShieldWeb.OrganisationLive.OrganisationForm do
  alias AshThreatShield.DynamicAttribute
  use ThreatShieldWeb, :live_component

  import ThreatShieldWeb.FormHelpers

  alias ThreatShield.Accounts.Organisation
  import ThreatShield.Accounts.Organisation, only: [attributes_config: 0]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
      </.header>

      <.simple_form
        for={@form}
        id="organisation-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:location]}
          type="select"
          label="Choose your location"
          options={@locations_options}
        />
        <%= for attribute <- @attributes do %>
          <.input
            name={attribute.name}
            value={Map.get(@attribute_map, attribute.name, "")}
            type="text"
            label={attribute.name}
          />
          <em>e.g. <%= DynamicAttribute.get_suggestions(attribute) |> Enum.join(", ") %></em>
        <% end %>
        <:actions>
          <.button_primary phx-disable-with="Saving...">Save Organisation</.button_primary>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{organisation: organisation} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(build_form(assigns))
     |> assign(:attribute_map, organisation.attributes || %{})}
  end

  @impl true
  def handle_event("validate", %{"organisation" => organisation_params}, socket) do
    {:noreply, validate_form(socket, organisation_params)}
  end

  def handle_event("save", %{"organisation" => organisation_params} = params, socket) do
    attributes = extract_attributes_from_params(params)
    message = success_message(socket.assigns.action)

    {socket, _result} =
      submit_form(
        socket,
        Map.put(organisation_params, "attributes", attributes),
        __MODULE__,
        message
      )

    noreply(socket)
  end

  defp build_form(%{action: :edit_organisation, organisation: organisation, current_user: user}) do
    AshPhoenix.Form.for_update(organisation, :update, actor: user, as: "organisation")
  end

  defp build_form(%{action: :new, current_user: user}) do
    AshPhoenix.Form.for_create(Organisation, :create, actor: user, as: "organisation")
  end

  defp success_message(:edit_organisation), do: "Organisation updated successfully"
  defp success_message(:new), do: "Organisation created successfully"

  defp extract_attributes_from_params(params) do
    attributes_config()
    |> Enum.map(fn d -> {d.name, Map.get(params, d.name, "")} end)
    |> Map.new()
  end
end
