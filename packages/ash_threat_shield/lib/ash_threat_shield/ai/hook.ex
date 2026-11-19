defmodule AshThreatShield.AI.Hook do
  @moduledoc """
  Called by the suggestion actions of `AshThreatShield.ThreatManagement.ThreatModel`
  after the policies and the reads of the records in focus, and before the request
  to the language model. A host uses it e.g. to count a quota:

      config :ash_threat_shield, :ai_hook, MyApp.AiQuota

  Without a hook, every request is allowed.
  """

  @doc """
  Allows the request with `:ok`, or refuses it with `{:error, error}`; the action
  then returns the error and does not call the language model.

  `organisation` is the record of the owner resource, read with the actor. `kind` is
  what is suggested: `:assets`, `:threats`, `:risks` or `:mitigations`.
  """
  @callback before_ai_request(organisation :: struct(), actor :: term(), kind :: atom()) ::
              :ok | {:error, term()}

  @doc """
  Calls the configured hook, or returns `:ok` without one.
  """
  @spec run(struct(), term(), atom()) :: :ok | {:error, term()}
  def run(organisation, actor, kind) do
    case Application.get_env(:ash_threat_shield, :ai_hook) do
      nil -> :ok
      hook -> hook.before_ai_request(organisation, actor, kind)
    end
  end
end
