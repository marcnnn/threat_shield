defmodule ThreatShieldWeb.FormHelpers do
  @moduledoc """
  Shared functions for the form components, which edit Ash resources with
  `AshPhoenix.Form`.

  A form component gets the assign `:patch` from its parent: the path to return to
  after a successful save.
  """

  import Phoenix.Component, only: [assign: 3, to_form: 1]
  import Phoenix.LiveView, only: [put_flash: 3, push_patch: 2]

  @doc """
  Assigns the form as `:form`.
  """
  def assign_form(socket, %AshPhoenix.Form{} = form), do: assign(socket, :form, to_form(form))
  def assign_form(socket, %Phoenix.HTML.Form{} = form), do: assign(socket, :form, form)

  @doc """
  Validates the form in the assign `:form` with the parameters.
  """
  def validate_form(socket, params) do
    assign_form(socket, AshPhoenix.Form.validate(socket.assigns.form, params))
  end

  @doc """
  Submits the form in the assign `:form` with the parameters and handles the result
  with `handle_save_result/4`. `action_opts` go to the action, e.g. `load:`. Returns
  the socket and the result.
  """
  def submit_form(socket, params, form_module, message, action_opts \\ []) do
    result = AshPhoenix.Form.submit(socket.assigns.form, params: params, action_opts: action_opts)
    {handle_save_result(socket, result, form_module, message), result}
  end

  @doc """
  Handles the result of a submitted form.

  On success, it sends `{form_module, {:saved, entity}}` to the parent LiveView,
  shows the message, and returns to the path in the assign `:patch`. On an error,
  it shows the form with the errors.
  """
  def handle_save_result(socket, {:ok, entity}, form_module, message) do
    send(self(), {form_module, {:saved, entity}})

    socket
    |> put_flash(:info, message)
    |> push_patch(to: socket.assigns.patch)
  end

  def handle_save_result(socket, {:error, form}, _form_module, _message) do
    assign_form(socket, form)
  end
end
