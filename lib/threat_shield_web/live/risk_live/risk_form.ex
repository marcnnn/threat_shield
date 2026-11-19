defmodule ThreatShieldWeb.RiskLive.RiskForm do
  use ThreatShieldWeb, :live_component

  import ThreatShieldWeb.FormHelpers

  alias AshThreatShield.ThreatManagement.Risk
  alias ThreatShieldWeb.Labels

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
      </.header>
      <p class="help-text">
        <%= dgettext(
          "risks",
          "Risk: short description"
        ) %>
      </p>

      <.simple_form
        for={@form}
        id="risk-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="text" label="Description" />
        <.input
          field={@form[:status]}
          type="select"
          label={dgettext("risks", "Status")}
          options={status_options()}
        >
        </.input>
        <div class="my-2">
          <.criticality_picker field={@form[:severity]} label={dgettext("risks", "Severity")} />
        </div>
        <div class="grid grid-cols-2 space-x-4">
          <.input
            field={@form[:estimated_cost]}
            type="number"
            label={dgettext("risks", "Estimated cost per indicence in EUR")}
          />
          <.input
            field={@form[:probability]}
            type="number"
            label="Frequency of incidences per year"
            step="0.1"
            min="0"
          />
        </div>
        <hr />
        <:actions>
          <.button_primary phx-disable-with={dgettext("common", "Saving...")}>
            Save Risk
          </.button_primary>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(build_form(assigns))}
  end

  @impl true
  def handle_event("validate", %{"risk" => risk_params}, socket) do
    {:noreply, validate_form(socket, risk_params)}
  end

  def handle_event("save", %{"risk" => risk_params}, socket) do
    {socket, _result} =
      submit_form(socket, risk_params, __MODULE__, success_message(socket.assigns.action))

    noreply(socket)
  end

  def status_options() do
    Labels.available_risk_states()
    |> Enum.map(fn {key, label} -> {label, key} end)
  end

  defp build_form(%{action: :edit_risk, risk: risk, current_user: user}) do
    AshPhoenix.Form.for_update(risk, :update, actor: user, as: "risk")
  end

  defp build_form(%{action: :new_risk, threat: threat, current_user: user}) do
    AshPhoenix.Form.for_create(Risk, :create,
      actor: user,
      as: "risk",
      # the risk belongs to the threat of the page, whatever the client sends
      transform_params: fn params, _type -> Map.put(params, "threat_id", threat.id) end
    )
  end

  defp success_message(:edit_risk), do: "Risk updated successfully"
  defp success_message(:new_risk), do: "Risk created successfully"
end
