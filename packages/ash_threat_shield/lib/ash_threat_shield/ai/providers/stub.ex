defmodule AshThreatShield.AI.Providers.Stub do
  @moduledoc """
  An `AshThreatShield.AI.Provider` for tests, without a language model:

      config :ash_threat_shield, :ai_provider, AshThreatShield.AI.Providers.Stub

  It answers with two items in the JSON format that the request asks for.

  A test can change this with the application environment of `:ash_threat_shield`:

    * `:ai_stub_listener` - a pid that gets `{:ai_request, messages}` for each
      request
    * `:ai_stub_result` - the result to return, e.g. `{:error, :timeout}`
  """

  @behaviour AshThreatShield.AI.Provider

  @impl true
  def chat(messages, _opts) do
    if listener = Application.get_env(:ash_threat_shield, :ai_stub_listener) do
      send(listener, {:ai_request, messages})
    end

    Application.get_env(:ash_threat_shield, :ai_stub_result) || {:ok, suggestions(messages)}
  end

  defp suggestions(messages) do
    text = Enum.map_join(messages, "\n", & &1.content)
    [_, root_key, field] = Regex.run(~r/\{"(\w+)": \[\{"(\w+)":/, text)

    items =
      case field do
        "value" ->
          [%{"value" => "Example 1"}, %{"value" => "Example 2"}]

        _ ->
          [
            %{"name" => "Suggestion 1", "description" => "Description 1"},
            %{"name" => "Suggestion 2", "description" => "Description 2"}
          ]
      end

    Jason.encode!(%{root_key => items})
  end
end
