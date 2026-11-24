defmodule ThreatShieldWeb.MembersLive.InviteForm do
  use ThreatShieldWeb, :live_component

  import ThreatShieldWeb.FormHelpers

  alias ThreatShield.Accounts.Invite

  @impl true
  def render(assigns) do
    ~H"""
    <div class="md:w-[800px]">
      <.header>
        {@title}
      </.header>
      <.h3>
        <span class="text-gray-700 inline-block">
          <Icons.organisation_icon class="w-5 h-5" />
        </span>
        {@organisation.name}
      </.h3>

      <.simple_form
        for={@form}
        id="invite-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:email]} type="text" label="Email" />
        <:actions>
          <div class="w-full text-end">
            <.button_primary phx-disable-with="Saving...">
              <.icon name="hero-envelope" class="h-5 w-5 me-2" />
              {dgettext("organisation", "Send invite")}
            </.button_primary>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{organisation: organisation, current_user: user} = assigns, socket) do
    form =
      AshPhoenix.Form.for_create(Invite, :create,
        actor: user,
        as: "invite",
        # the invite is for the organisation of the page, whatever the client sends
        transform_params: fn params, _type ->
          Map.put(params, "organisation_id", organisation.id)
        end
      )

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(form)}
  end

  @impl true
  def handle_event("validate", %{"invite" => invite_params}, socket) do
    {:noreply, validate_form(socket, invite_params)}
  end

  def handle_event("save", %{"invite" => invite_params}, socket) do
    {socket, _result} =
      submit_form(socket, invite_params, __MODULE__, "Invite created successfully",
        load: [:organisation]
      )

    noreply(socket)
  end
end
