defmodule ThreatShieldWeb.MembersLive.RoleForm do
  use ThreatShieldWeb, :live_component

  import ThreatShieldWeb.FormHelpers

  @role_options Enum.map(ThreatShield.Accounts.Role.values(), &{&1, Atom.to_string(&1)})

  @impl true
  def render(assigns) do
    ~H"""
    <div class="md:w-[800px]">
      <.header>
        <%= dgettext("organisation", "Edit role for") %> <%= @membership.user.email %>
      </.header>

      <.simple_form
        for={@form}
        id={"role-form-for-user-#{@membership.user_id}"}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:role]}
          type="select"
          label="Role"
          options={
            @role_options
            |> Enum.map(fn {_, v} ->
              {Gettext.dgettext(ThreatShieldWeb.Gettext, "organisation", v), v}
            end)
          }
        />
        <:actions>
          <div class="w-full text-end">
            <.button_primary phx-disable-with="Saving...">
              <%= dgettext("organisation", "Save Membership") %>
            </.button_primary>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{membership: membership, current_user: user} = assigns, socket) do
    form = AshPhoenix.Form.for_update(membership, :update_role, actor: user, as: "membership")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:role_options, @role_options)
     |> assign_form(form)}
  end

  @impl true
  def handle_event("validate", %{"membership" => membership_params}, socket) do
    {:noreply, validate_form(socket, membership_params)}
  end

  def handle_event("save", %{"membership" => membership_params}, socket) do
    {socket, _result} =
      submit_form(socket, membership_params, __MODULE__, "Role updated successfully")

    noreply(socket)
  end
end
