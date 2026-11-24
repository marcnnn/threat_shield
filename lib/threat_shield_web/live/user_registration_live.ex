defmodule ThreatShieldWeb.UserRegistrationLive do
  use ThreatShieldWeb, :live_view

  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div class="md:flex md:h-full">
      <div class="md:w-1/2 md:flex flex-col justify-stretch px-4 md:px-12 xl:px-20 h-full bg-white md:shadow-sm md:shadow-lg shadow-primary-300">
        <div class="grow h-16 md:h-32 pt-2">
          <.flash_group flash={@flash} />
        </div>
        <main class="xl:w-xl mx-auto">
          <.header class="text-center">
            <div class="threadshield-header text-4xl md:text-6xl xl:text-8xl">
              {dgettext("accounts", "Join us")}
            </div>
            <div class="threadshield-header md:text-2xl mb-5">
              {dgettext("accounts", "in our beta phase.")}
            </div>
            <:subtitle>
              Already registered?
              <.link
                navigate={~p"/users/log_in"}
                class="font-semibold text-primary-500 hover:underline"
              >
                {dgettext("accounts", "Sign in")}
              </.link>
              to your account now.
            </:subtitle>
          </.header>

          <.simple_form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            action={~p"/users/log_in?_action=registered"}
            method="post"
          >
            <.error :if={@check_errors}>
              Oops, something went wrong! Please check the errors below.
            </.error>

            <div class="grid grid-cols-2 gap-4">
              <.input field={@form[:first_name]} label="First name" required />
              <.input field={@form[:last_name]} label="Last name" required />
            </div>

            <.input field={@form[:email]} type="email" label="Email" required autocomplete="off" />
            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              required
              autocomplete="new-password"
            />

            <label class="flex items-center gap-4 text-sm leading-6">
              <.input field={@form[:accept_toc]} type="checkbox" required />
              <span>
                {dgettext("accounts", "By checking this box, you agree to our")}
                <a href="https://threatshield.eu/terms.html" target="_blank" class="text-primary-500">
                  {dgettext("accounts", "Terms of Service")}
                </a>
                and our <a
                  href="https://threatshield.eu/privacy.html"
                  target="_blank"
                  class="text-primary-500"
                >
                <%= dgettext("accounts", "Privacy Policy") %>
                </a>.
              </span>
            </label>

            <:actions>
              <.button_magic phx-disable-with="Creating account..." class="text-lg w-full">
                {dgettext("accounts", "Sign up")}
              </.button_magic>
            </:actions>
          </.simple_form>
        </main>
        <footer class="grow text-center justify-center md:justify-end text-xs h-32 bg-white">
          <div class="p-4 space-x-6">
            <a href="https://threatshield.eu" class="text-gray-500">
              threatshield.eu
            </a>
            <a href="https://inspired.consulting" class="text-gray-500">
              inspired.consulting
            </a>
          </div>
        </footer>
      </div>
      <div class="hidden md:block w-1/2">
        <img src={~p"/images/shiba-dancing.png"} alt="" class="w-full h-full object-cover" />
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(
      trigger_submit: false,
      check_errors: false
    )
    |> ok(layout: {ThreatShieldWeb.Layouts, :unauthenticated})
  end

  @impl true
  def handle_params(%{"token" => token}, _url, socket) when is_binary(token) do
    # The token is the secret of the invite link, so no actor is needed
    case Accounts.get_invite_by_token!(token) do
      %Accounts.Invite{} = invite ->
        socket
        |> assign(:token, token)
        |> assign(:invite, invite)
        |> assign(:form, registration_form(%{"email" => to_string(invite.email)}))
        |> noreply()

      nil ->
        socket
        |> clear_flash()
        |> put_flash(:error, dgettext("accounts", "Invalid invitation token."))
        |> push_navigate(to: ~p"/users/register")
        |> noreply()
    end
  end

  def handle_params(_params, _url, socket) do
    socket
    |> assign(:form, registration_form(%{}))
    |> noreply()
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: user_params) do
      {:ok, user} ->
        maybe_join_organisation(user, socket.assigns[:token])

        # The form now posts the address and the password to the session
        # controller, which signs the user in.
        form = AshPhoenix.Form.validate(socket.assigns.form, user_params, errors: false)

        socket
        |> assign(trigger_submit: true, check_errors: false, form: form)
        |> noreply()

      {:error, form} ->
        socket
        |> assign(check_errors: true, form: form)
        |> noreply()
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)

    socket
    |> assign(form: form)
    |> assign(check_errors: socket.assigns.check_errors and not form.source.valid?)
    |> noreply()
  end

  # The registration sends the confirmation instructions
  defp registration_form(params) do
    User
    # a visitor without an account registers; there is no actor
    # credo:disable-for-next-line CredoChecks.ActorInWebCalls
    |> AshPhoenix.Form.for_create(:register_with_password, as: "user", params: params)
    |> to_form()
  end

  defp maybe_join_organisation(%User{}, nil), do: :ok

  defp maybe_join_organisation(%User{} = user, token) do
    Accounts.join_with_token(token, actor: user)
  end
end
