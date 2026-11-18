defmodule ThreatShieldWeb.UserResetPasswordLive do
  use ThreatShieldWeb, :live_view

  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Reset Password</.header>

      <.simple_form
        for={@form}
        id="reset_password_form"
        phx-submit="reset_password"
        phx-change="validate"
      >
        <.error :if={@form.errors != []}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input field={@form[:password]} type="password" label="New password" required />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          required
        />
        <:actions>
          <.button_primary phx-disable-with="Resetting..." class="w-full">
            Reset Password
          </.button_primary>
        </:actions>
      </.simple_form>

      <p class="text-center text-sm mt-4">
        <.link href={~p"/users/register"}>Sign up</.link>
        | <.link href={~p"/users/log_in"}>Sign in</.link>
      </p>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_reset_token(token) do
      {:ok, %User{} = user} ->
        {:ok, assign(socket, :form, reset_form(user, token))}

      _ ->
        socket
        |> put_flash(:error, "Reset password link is invalid or it has expired.")
        |> redirect(to: ~p"/")
        |> ok()
    end
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: user_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/users/log_in")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, user_params))}
  end

  defp reset_form(user, token) do
    user
    |> AshPhoenix.Form.for_update(:password_reset_with_password,
      as: "user",
      prepare_params: fn params, _phase -> Map.put(params, "reset_token", token) end
    )
    |> to_form()
  end
end
