defmodule AshThreatShield.Test.AiHook do
  @moduledoc """
  The `AshThreatShield.AI.Hook` of the test host. It allows every request, and a test
  can change this with the application environment of `:ash_threat_shield`:

    * `:ai_hook_listener` - a pid that gets `{:ai_hook, organisation, actor, kind}`
    * `:ai_hook_result` - the result to return, e.g. `{:error, :quota_exceeded}`
  """
  @behaviour AshThreatShield.AI.Hook

  @impl true
  def before_ai_request(organisation, actor, kind) do
    if listener = Application.get_env(:ash_threat_shield, :ai_hook_listener) do
      send(listener, {:ai_hook, organisation, actor, kind})
    end

    Application.get_env(:ash_threat_shield, :ai_hook_result, :ok)
  end
end
