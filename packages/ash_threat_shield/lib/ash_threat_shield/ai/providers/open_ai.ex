# The dependency `openai` is optional: without it, this provider is not compiled.
if Code.ensure_loaded?(OpenAI) do
  defmodule AshThreatShield.AI.Providers.OpenAI do
    @moduledoc """
    The default `AshThreatShield.AI.Provider`: the chat completion API of OpenAI, with
    the key from the configuration of the `openai` package. It needs the optional
    dependency `openai`.

    The model can be set with the option `:model` or the configuration
    `config :ash_threat_shield, AshThreatShield.AI.Providers.OpenAI, model: "..."`.
    """

    @behaviour AshThreatShield.AI.Provider

    require Logger

    @default_model "gpt-3.5-turbo"

    @impl true
    def chat(messages, opts \\ []) do
      case OpenAI.chat_completion(model: model(opts), messages: messages) do
        {:ok, %{choices: [%{"message" => %{"content" => content}} | _]}}
        when is_binary(content) ->
          {:ok, content}

        {:ok, response} ->
          Logger.error("Unexpected response from OpenAI: #{inspect(response)}")
          {:error, :unexpected_response}

        {:error, %{"error" => error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp model(opts) do
      Keyword.get_lazy(opts, :model, fn ->
        :ash_threat_shield
        |> Application.get_env(__MODULE__, [])
        |> Keyword.get(:model, @default_model)
      end)
    end
  end
end
