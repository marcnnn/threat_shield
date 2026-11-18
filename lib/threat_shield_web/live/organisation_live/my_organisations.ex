defmodule ThreatShieldWeb.OrganisationLive.MyOrganisations do
  use ThreatShieldWeb, :live_view

  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.Errors.InviteError
  alias ThreatShield.Accounts.Organisation
  alias ThreatShieldWeb.Locations

  import ThreatShield.Accounts.Organisation, only: [attributes_config: 0]
  import ThreatShieldWeb.Helpers, only: [format_datetime: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> stream_organisations()
    |> assign(:locations_options, Locations.list_locations())
    |> assign(:attributes, attributes_config())
    |> assign_open_invitations()
    |> ok()
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket
    |> apply_action(socket.assigns.live_action, params)
    |> noreply()
  end

  defp apply_action(socket, :new, _params) do
    %{current_user: current_user} = socket.assigns

    socket
    |> assign(:page_title, "New Organisation")
    |> assign(:edit_organisation, %Organisation{users: [current_user]})
    |> assign(:attributes, attributes_config())
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Organisations")
    |> assign(:edit_organisation, nil)
    |> assign(:attributes, attributes_config())
  end

  @impl true
  def handle_info(
        {ThreatShieldWeb.OrganisationLive.OrganisationForm, {:saved, organisation}},
        socket
      ) do
    {:noreply, stream_insert(socket, :organisations, organisation)}
  end

  @impl true
  def handle_event("reject_invitation", %{"invite_id" => invite_id}, socket) do
    socket =
      case Accounts.reject_invite(invite_id, actor: socket.assigns.current_user) do
        :ok ->
          socket

        {:error, _error} ->
          put_flash(socket, :error, dgettext("members", "This invitation is not valid any more."))
      end

    socket
    |> assign_open_invitations()
    |> noreply()
  end

  @impl true
  def handle_event("accept_invitation", %{"invite_id" => invite_id}, socket) do
    user = socket.assigns.current_user

    case accept_invite(user, invite_id) do
      {:ok, membership} ->
        socket
        |> stream_insert(:organisations, membership.organisation)
        |> assign_open_invitations()
        |> noreply()

      {:error, :already_member} ->
        socket
        |> put_flash(:info, dgettext("members", "You are already a member of this organisation."))
        |> noreply()

      {:error, :email_not_confirmed} ->
        socket
        |> put_flash(
          :error,
          dgettext(
            "members",
            "Please confirm your email address before you accept an invitation."
          )
        )
        |> noreply()

      {:error, _reason} ->
        socket
        |> put_flash(:error, dgettext("members", "This invitation is not valid any more."))
        |> assign_open_invitations()
        |> noreply()
    end
  end

  defp accept_invite(user, invite_id) do
    case Accounts.accept_invite(invite_id, actor: user, load: [:organisation]) do
      {:ok, membership} -> {:ok, membership}
      {:error, error} -> {:error, InviteError.reason(error)}
    end
  end

  defp stream_organisations(socket) do
    organisations = Accounts.list_organisations!(actor: socket.assigns.current_user)

    socket
    |> assign(:has_memberships, not Enum.empty?(organisations))
    |> stream(:organisations, organisations)
  end

  defp assign_open_invitations(%{assigns: %{current_user: user}} = socket) do
    open_invitations = Accounts.list_received_invites!(actor: user, load: [:organisation_name])

    socket
    |> assign(:open_invitations, open_invitations)
  end
end
