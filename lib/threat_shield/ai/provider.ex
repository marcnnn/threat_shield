defmodule ThreatShield.AI.Provider do
  @moduledoc """
  A language model that answers the chat requests of `ThreatShield.AI`.

  The provider is read from the configuration `:ai_provider` of `:threat_shield`
  (default: `ThreatShield.AI.Providers.OpenAI`). Tests use a stub.

  `ThreatShield.AI` asks for answers in JSON. The provider returns the text of the
  answer; parsing it is the job of `ThreatShield.AI`.
  """

  @typedoc "A chat message, e.g. `%{role: \"system\", content: \"...\"}`."
  @type message :: %{role: String.t(), content: String.t()}

  @doc """
  Sends the messages and returns the text of the answer.
  """
  @callback chat(messages :: [message()], opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  The configured provider.
  """
  @spec configured() :: module()
  def configured do
    Application.get_env(:threat_shield, :ai_provider, ThreatShield.AI.Providers.OpenAI)
  end
end
