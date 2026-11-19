defmodule AshThreatShield do
  @moduledoc """
  Threat modeling with Ash: the systems, assets, threats, risks and mitigations of an
  organisation, the policies that guard them, the descriptions and risk summaries of
  a threat model, and suggestions of an AI assistant.

  The host application provides what the library does not own. See the README for
  every option of `config :ash_threat_shield`:

    * `:repo` - the `AshPostgres.Repo` of the resources (compile time)
    * `:owner_resource` - the Ash resource of the organisations that own the threat
      models (compile time), see `AshThreatShield.Owner`
    * `:authorization` - the module that decides the rights of an actor in an
      organisation, see `AshThreatShield.Authorization`
    * `:ai_provider` - the language model, see `AshThreatShield.AI.Provider`
    * `:ai_hook` - called before each AI request, e.g. to count a quota, see
      `AshThreatShield.AI.Hook`
  """

  @owner_resource Application.compile_env!(:ash_threat_shield, :owner_resource)

  @doc """
  The resource of the organisations (`config :ash_threat_shield, :owner_resource`).
  """
  @spec owner_resource() :: module()
  def owner_resource, do: @owner_resource
end
