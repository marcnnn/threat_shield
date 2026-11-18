defmodule ThreatShieldWeb.UserSettingsLive do
  use ThreatShieldWeb, :live_view

  alias ThreatShield.Accounts
  alias ThreatShieldWeb.{AshErrors, UserAuth}

  def render(assigns) do
    ~H"""
    <section class="w-full bg-white py-4 shadow-primary-200 shadow-sm">
      <div class="ts-container">
        <.header class="text-center">
          Account Settings
          <:subtitle>Manage your account email address and password settings</:subtitle>
        </.header>

        <div class="space-y-12 divide-y">
          <div>
            <.simple_form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
            >
              <.input field={@email_form[:email]} type="email" label="Email" required />
              <.input
                field={@email_form[:current_password]}
                name="current_password"
                id="current_password_for_email"
                type="password"
                label="Current password"
                value={@email_form_current_password}
                required
              />
              <:actions>
                <.button_primary phx-disable-with="Changing...">Change Email</.button_primary>
              </:actions>
            </.simple_form>
          </div>
          <div>
            <.simple_form
              for={@password_form}
              id="password_form"
              action={~p"/users/log_in?_action=password_updated"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
            >
              <.input
                field={@password_form[:email]}
                type="hidden"
                id="hidden_user_email"
                value={@current_email}
              />
              <.input field={@password_form[:password]} type="password" label="New password" required />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label="Confirm new password"
              />
              <.input
                field={@password_form[:current_password]}
                name="current_password"
                type="password"
                label="Current password"
                id="current_password_for_password"
                value={@current_password}
                required
              />
              <:actions>
                <.button_primary phx-disable-with="Changing...">Change Password</.button_primary>
              </:actions>
            </.simple_form>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    user = socket.assigns.current_user

    socket =
      case Accounts.confirm_user_email_change(user, token, actor: user) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, email_form(user))
      |> assign(:password_form, password_form(user))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  # The current password is a separate parameter, see the inputs of the forms
  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      AshPhoenix.Form.validate(socket.assigns.email_form, with_password(user_params, password))

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  # Sends a confirmation link to the new address. The address is changed when the
  # link is followed.
  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    case AshPhoenix.Form.submit(socket.assigns.email_form,
           params: with_password(user_params, password)
         ) do
      {:ok, _user} ->
        info = "A link to confirm your email change has been sent to the new address."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> assign(email_form_current_password: nil)
         |> assign(email_form: email_form(socket.assigns.current_user))}

      {:error, email_form} ->
        {:noreply, assign(socket, :email_form, email_form)}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      AshPhoenix.Form.validate(
        socket.assigns.password_form,
        with_password(user_params, password)
      )

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  # Changing the password signs the user out everywhere. The form then posts the
  # address and the new password to the session controller, which signs the user in
  # again.
  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    case AshPhoenix.Form.submit(socket.assigns.password_form,
           params: with_password(user_params, password)
         ) do
      {:ok, _user} ->
        password_form =
          AshPhoenix.Form.validate(
            socket.assigns.password_form,
            with_password(user_params, password),
            errors: false
          )

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, password_form} ->
        {:noreply, assign(socket, password_form: password_form)}
    end
  end

  defp with_password(user_params, password),
    do: Map.put(user_params, "current_password", password)

  defp email_form(user) do
    user
    |> AshPhoenix.Form.for_update(:change_email,
      as: "user",
      actor: user,
      context: UserAuth.account_urls_context(),
      post_process_errors: &AshErrors.post_process_error/3
    )
    |> to_form()
  end

  defp password_form(user) do
    user
    |> AshPhoenix.Form.for_update(:change_password,
      as: "user",
      actor: user,
      post_process_errors: &AshErrors.post_process_error/3
    )
    |> to_form()
  end
end
