defmodule ThreatShieldWeb.UserSettingsLive do
  use ThreatShieldWeb, :live_view

  alias ThreatShield.Accounts

  import ThreatShieldWeb.Helpers, only: [format_datetime: 1]

  @api_key_validity_days [30, 90, 365]

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
          <div id="api_keys" class="pt-8">
            <.h3><%= dgettext("accounts", "API keys") %></.h3>
            <p class="mt-2 text-sm text-gray-700">
              <%= dgettext(
                "accounts",
                "Chat agents such as Claude use an API key to work with your organisations through the MCP server at %{url}. A key has your rights.",
                url: @mcp_url
              ) %>
            </p>

            <div
              :if={@new_api_key}
              id="new_api_key"
              class="mt-4 rounded-lg border border-primary-300 bg-primary-50 p-4"
            >
              <p class="text-sm font-semibold">
                <%= dgettext("accounts", "Copy the key now. It is not shown again.") %>
              </p>
              <code class="mt-2 block break-all text-sm"><%= @new_api_key %></code>
            </div>

            <.simple_form for={@api_key_form} id="api_key_form" phx-submit="create_api_key">
              <.input
                field={@api_key_form[:valid_for_days]}
                type="select"
                label={dgettext("accounts", "Valid for")}
                options={@api_key_validity_options}
              />
              <:actions>
                <.button_primary phx-disable-with="Creating...">
                  <%= dgettext("accounts", "Create API key") %>
                </.button_primary>
              </:actions>
            </.simple_form>

            <table :if={@api_keys != []} class="mt-6 w-full text-sm">
              <thead class="text-left text-gray-600">
                <tr>
                  <th class="py-1"><%= dgettext("accounts", "Created") %></th>
                  <th class="py-1"><%= dgettext("accounts", "Expires") %></th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={api_key <- @api_keys} id={"api_key-#{api_key.id}"}>
                  <td class="py-1"><%= format_datetime(api_key.inserted_at) %></td>
                  <td class="py-1">
                    <%= format_datetime(api_key.expires_at) %>
                    <span :if={!api_key.valid} class="text-gray-500">
                      (<%= dgettext("accounts", "expired") %>)
                    </span>
                  </td>
                  <td class="py-1 text-right">
                    <.button_secondary
                      phx-click="revoke_api_key"
                      phx-value-id={api_key.id}
                      data-confirm={dgettext("accounts", "Revoke this API key?")}
                    >
                      <%= dgettext("accounts", "Revoke") %>
                    </.button_secondary>
                  </td>
                </tr>
              </tbody>
            </table>
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
      |> assign(:mcp_url, url(~p"/mcp"))
      |> assign(:new_api_key, nil)
      |> assign(:api_key_form, to_form(%{"valid_for_days" => "90"}, as: "api_key"))
      |> assign(:api_key_validity_options, api_key_validity_options())
      |> assign_api_keys()

    {:ok, socket}
  end

  # The key itself is shown once, right after it was created; only its hash is stored.
  def handle_event("create_api_key", %{"api_key" => %{"valid_for_days" => days}}, socket) do
    user = socket.assigns.current_user
    days = if days in Enum.map(@api_key_validity_days, &to_string/1), do: days, else: "90"

    case Accounts.create_api_key(String.to_integer(days), actor: user) do
      {:ok, api_key} ->
        {:noreply,
         socket
         |> assign(:new_api_key, api_key.__metadata__.plaintext_api_key)
         |> assign_api_keys()}

      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, dgettext("accounts", "The API key was not created."))}
    end
  end

  def handle_event("revoke_api_key", %{"id" => id}, socket) do
    case Accounts.revoke_api_key(id, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> assign(:new_api_key, nil)
         |> put_flash(:info, dgettext("accounts", "The API key was revoked."))
         |> assign_api_keys()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, dgettext("accounts", "The API key was not found."))}
    end
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
    |> AshPhoenix.Form.for_update(:change_email, as: "user", actor: user)
    |> to_form()
  end

  defp password_form(user) do
    user
    |> AshPhoenix.Form.for_update(:change_password,
      as: "user",
      actor: user
    )
    |> to_form()
  end

  defp assign_api_keys(socket) do
    api_keys =
      Accounts.list_api_keys!(
        actor: socket.assigns.current_user,
        query: [sort: [inserted_at: :desc]],
        load: [:valid]
      )

    assign(socket, :api_keys, api_keys)
  end

  defp api_key_validity_options do
    Enum.map(@api_key_validity_days, fn days ->
      {dngettext("accounts", "%{count} day", "%{count} days", days), to_string(days)}
    end)
  end
end
