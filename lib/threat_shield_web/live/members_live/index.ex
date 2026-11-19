defmodule ThreatShieldWeb.MembersLive.Index do
  @moduledoc """
  LiveView for the members index page.
  """
  use ThreatShieldWeb, :live_view

  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.Invite
  alias ThreatShield.Accounts.{Membership, Organisation, User}

  import ThreatShieldWeb.Helpers, only: [add_breadcrumbs: 2, format_datetime: 1]
  import ThreatShieldWeb.Labels

  @impl true
  def mount(%{"org_id" => org_id}, _session, socket) do
    %User{} = user = socket.assigns.current_user
    %Organisation{} = organisation = get_organisation!(user, org_id)

    socket
    |> assign(:organisation, organisation)
    |> assign(:current_org_membership, organisation.actor_membership)
    |> assign(:owner_count, organisation.owner_count)
    |> ok()
  end

  @impl true
  def handle_params(params, url, socket) do
    socket
    |> add_breadcrumbs(url)
    |> apply_action(socket.assigns.live_action, params)
    |> noreply()
  end

  defp apply_action(socket, :new_invite, _params) do
    socket
    |> assign(:page_title, "Invite new member")
    |> assign(:invite, %Invite{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Members")
    |> assign(:invite, nil)
  end

  @impl true
  def handle_info({ThreatShieldWeb.MembersLive.InviteForm, {:saved, invite}}, socket) do
    # the create action has sent the email
    socket
    |> assign(
      organisation: %{
        socket.assigns.organisation
        | invites: socket.assigns.organisation.invites ++ [invite]
      }
    )
    |> noreply()
  end

  @impl true
  def handle_info({ThreatShieldWeb.MembersLive.RoleForm, {:saved, _membership}}, socket) do
    user = socket.assigns.current_user
    organisation = get_organisation!(user, socket.assigns.organisation.id)

    socket
    |> assign(:organisation, organisation)
    |> assign(:current_org_membership, organisation.actor_membership)
    |> assign(:owner_count, organisation.owner_count)
    |> noreply()
  end

  @impl true
  def handle_event("delete_membership", %{"membership_id" => id}, socket) do
    user = socket.assigns.current_user
    user_id = user.id

    case destroy_membership(socket.assigns.organisation, id, user) do
      {:ok, %Membership{user_id: ^user_id}} ->
        {:noreply, push_navigate(socket, to: ~p"/organisations")}

      {:ok, membership} ->
        socket
        |> assign(
          organisation: %{
            socket.assigns.organisation
            | memberships: delete_by_id(socket.assigns.organisation.memberships, membership.id)
          }
        )
        |> noreply()

      {:error, _reason} ->
        socket
        |> put_flash(:error, dgettext("members", "This member cannot be removed."))
        |> noreply()
    end
  end

  @impl true
  def handle_event("edit_membership", %{"membership_id" => id}, socket) do
    organisation = socket.assigns.organisation

    socket
    |> assign(:live_action, :edit_membership)
    |> assign(
      :membership_to_edit,
      Enum.find(organisation.memberships, fn m -> m.id == String.to_integer(id) end)
    )
    |> noreply()
  end

  @impl true
  def handle_event("revoke_invite", %{"invite_id" => id}, socket) do
    case Accounts.revoke_invite(id, actor: socket.assigns.current_user, return_destroyed?: true) do
      {:ok, invite} ->
        socket
        |> assign(
          organisation: %{
            socket.assigns.organisation
            | invites: delete_by_id(socket.assigns.organisation.invites, invite.id)
          }
        )
        |> noreply()

      {:error, _reason} ->
        socket
        |> put_flash(:error, dgettext("members", "This invitation cannot be revoked."))
        |> noreply()
    end
  end

  defp destroy_membership(%Organisation{memberships: memberships}, id, user) do
    case Enum.find(memberships, &(to_string(&1.id) == id)) do
      nil -> {:error, :not_found}
      membership -> Accounts.destroy_membership(membership, actor: user, return_destroyed?: true)
    end
  end

  defp get_organisation!(user, id) do
    Accounts.get_organisation!(id,
      actor: user,
      load: [:invites, :owner_count, :actor_membership, memberships: [:user]]
    )
  end

  defp delete_by_id(list, id) do
    index = Enum.find_index(list, fn item -> item.id == id end)
    List.delete_at(list, index)
  end
end
