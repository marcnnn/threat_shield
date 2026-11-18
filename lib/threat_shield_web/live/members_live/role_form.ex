defmodule ThreatShieldWeb.MembersLive.RoleForm do
  use ThreatShieldWeb, :live_component

  import ThreatShieldWeb.FormHelpers

  alias ThreatShield.Members

  @role_options [
    {:owner, "owner"},
    {:editor, "editor"},
    {:viewer, "viewer"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="md:w-[800px]">
      <.header>
        <%= dgettext("organisation", "Edit role for") %> <%= @membership.user.email %>
      </.header>

      <.simple_form
        for={@form}
        id={"role-form-for-user-#{@membership.user.id}"}
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
  def update(%{membership: membership} = assigns, socket) do
    changeset = Members.change_membership(membership)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:role_options, @role_options)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"membership" => membership_params}, socket) do
    changeset =
      socket.assigns.membership
      |> Members.change_membership(membership_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"membership" => membership_params}, socket) do
    membership = socket.assigns.membership
    user = socket.assigns.current_user

    {role, _} =
      Enum.find(@role_options, fn {_, v} -> v == Map.get(membership_params, "role") end)

    result = Members.update_role(user, membership, role)

    case result do
      {:error, :last_owner} ->
        socket
        |> put_flash(:error, "Cannot change role: this is the last owner")
        |> noreply()

      result ->
        socket
        |> handle_save_result(result, __MODULE__, "Role updated successfully")
        |> noreply()
    end
  end
end
