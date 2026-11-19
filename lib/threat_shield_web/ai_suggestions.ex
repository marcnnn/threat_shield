defmodule ThreatShieldWeb.AiSuggestions do
  @moduledoc """
  The AI suggestion flow for list components.

  A list component

    * calls `request/2` to ask the AI assistant for suggestions, with a function
      that calls a suggestion action of `AshThreatShield.ThreatManagement` (e.g.
      `suggest_threats/3`) with the user as `actor:`. The action checks the right
      and the quota,
    * passes the result from its `handle_async/3` callback to `handle_result/2`,
    * and reads the suggestions that the user selected in the dialog with `selected/2`.

  The suggestions are kept in the assign `:ai_suggestions` of the component. The
  dialog is shown while `:show_suggest_dialog` is true. The component needs the
  assign `:origin`, the path to return to when a request fails.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [start_async: 4, put_flash: 3, push_navigate: 2]
  use Gettext, backend: ThreatShieldWeb.Gettext

  alias ThreatShield.Quotas.Errors.QuotaExceeded

  @doc """
  Opens the suggestion dialog and asks the AI assistant in the background.

  `fun` calls a suggestion action and returns `{:ok, suggestions}` or
  `{:error, error}`. It blocks until the language model has answered.
  """
  def request(socket, fun) when is_function(fun, 0) do
    socket
    |> assign(:ai_suggestions, nil)
    |> assign(:show_suggest_dialog, true)
    |> start_async(:ai_suggestions, fun, supervisor: ThreatShield.TaskSupervisor)
  end

  @doc """
  Handles the result of a request, as it is passed to `handle_async/3`.
  """
  def handle_result(socket, {:ok, {:ok, [_ | _] = suggestions}}) do
    assign(socket, :ai_suggestions, suggestions)
  end

  def handle_result(socket, {:ok, {:error, error}}) do
    if QuotaExceeded.exceeded?(error) do
      fail(socket, dgettext("common", "Your quota for AI suggestions is exceeded."))
    else
      fail_generic(socket)
    end
  end

  # an empty list or a crashed task
  def handle_result(socket, _result), do: fail_generic(socket)

  defp fail_generic(socket) do
    fail(
      socket,
      dgettext("common", "The AI assistant could not create suggestions. Please try again later.")
    )
  end

  @doc """
  Returns the suggestions that are selected in the parameters of the dialog form.
  """
  def selected(socket, %{"selected_suggestions" => names}) when is_list(names) do
    Enum.filter(socket.assigns[:ai_suggestions] || [], fn s -> s.name in names end)
  end

  def selected(_socket, _params), do: []

  defp fail(socket, message) do
    socket
    |> assign(:show_suggest_dialog, false)
    |> put_flash(:error, message)
    |> push_navigate(to: socket.assigns.origin)
  end
end
