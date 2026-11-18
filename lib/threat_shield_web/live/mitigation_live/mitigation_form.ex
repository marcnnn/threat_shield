defmodule ThreatShieldWeb.MitigationLive.MitigationForm do
  use ThreatShieldWeb, :live_component

  import ThreatShieldWeb.FormHelpers

  alias ThreatShield.ThreatManagement.Mitigation
  alias ThreatShieldWeb.Labels

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>
          <%= dgettext(
            "mitigations",
            "Mitigations: short description"
          ) %>
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="mitigation-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label={dgettext("mitigations", "Name")} />
        <.input
          field={@form[:description]}
          type="text"
          label={dgettext("mitigations", "Description")}
        />
        <.input field={@form[:issue_link]} type="text" label={dgettext("mitigations", "Issue link")} />
        <.input
          field={@form[:status]}
          type="select"
          label={dgettext("mitigations", "Status")}
          options={status_options()}
        />
        <.input
          field={@form[:implementation_notes]}
          type="text"
          label={dgettext("mitigations", "Implementation notes")}
        />
        <.input
          field={@form[:implementation_date]}
          type="date"
          label={dgettext("mitigations", "Implementation date")}
        />

        <hr />
        <.input
          field={@form[:verification_method]}
          type="text"
          label={dgettext("mitigations", "Verification method")}
        />
        <.input
          field={@form[:verification_result]}
          type="text"
          label={dgettext("mitigations", "Verification result")}
        />
        <.input
          field={@form[:verification_date]}
          type="date"
          label={dgettext("mitigations", "Verification date")}
        />

        <:actions>
          <.button_primary phx-disable-with="Saving...">Save Mitigation</.button_primary>
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
  def handle_event("validate", %{"mitigation" => mitigation_params}, socket) do
    {:noreply, validate_form(socket, mitigation_params)}
  end

  def handle_event("save", %{"mitigation" => mitigation_params}, socket) do
    {socket, _result} =
      submit_form(socket, mitigation_params, __MODULE__, success_message(socket.assigns.action))

    noreply(socket)
  end

  def status_options() do
    Labels.available_mitigation_states()
    |> Enum.map(fn {key, label} -> {label, key} end)
  end

  defp build_form(%{action: :edit_mitigation, mitigation: mitigation, current_user: user}) do
    AshPhoenix.Form.for_update(mitigation, :update, actor: user, as: "mitigation")
  end

  defp build_form(%{action: :new_mitigation, risk: risk, user: user}) do
    AshPhoenix.Form.for_create(Mitigation, :create,
      actor: user,
      as: "mitigation",
      # the mitigation belongs to the risk of the page, whatever the client sends
      transform_params: fn params, _type -> Map.put(params, "risk_id", risk.id) end
    )
  end

  defp success_message(:edit_mitigation), do: "Mitigation updated successfully"
  defp success_message(:new_mitigation), do: "Mitigation created successfully"
end
