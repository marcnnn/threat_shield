defmodule AshThreatShield.AI.Provider do
  @moduledoc """
  A language model that answers the chat requests of `AshThreatShield.AI`.

  The provider is read from `config :ash_threat_shield, :ai_provider` (default:
  `AshThreatShield.AI.Providers.OpenAI`). Tests use
  `AshThreatShield.AI.Providers.Stub`.

  `AshThreatShield.AI` asks for answers in JSON. The provider returns the text of the
  answer; parsing it is the job of `AshThreatShield.AI`.
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
    Application.get_env(:ash_threat_shield, :ai_provider, AshThreatShield.AI.Providers.OpenAI)
  end
end
