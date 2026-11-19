defmodule AshThreatShield.Owner do
  @moduledoc """
  The organisation that owns a threat model. The host application configures its
  resource:

      config :ash_threat_shield, :owner_resource, MyApp.Accounts.Organisation

  The library resources `belongs_to :organisation` of this resource, with the
  column `organisation_id`. The resource needs

    * an integer primary key `id`,
    * a `name` (string) and optionally `attributes` (a map of property names to
      texts), which describe the organisation in the context of the AI assistant,
    * read policies: the library reads the organisation with the actor, and an
      organisation that the actor may not read is not found.

  Relationships back to the library resources (`has_many :systems` etc.) and counts
  are optional; the library does not use them.

  The resource may implement this behaviour to describe its `attributes`.
  """

  @doc """
  The properties that an organisation can have in its map `attributes`, with their
  descriptions for the AI assistant.
  """
  @callback attributes_config() :: [AshThreatShield.DynamicAttribute.t()]

  @optional_callbacks attributes_config: 0

  @doc """
  The descriptions of the properties of the configured owner resource, or `[]`.
  """
  @spec attributes_config() :: [AshThreatShield.DynamicAttribute.t()]
  def attributes_config do
    owner = AshThreatShield.owner_resource()

    if Code.ensure_loaded?(owner) and function_exported?(owner, :attributes_config, 0) do
      # not a remote call at compile time: the module belongs to the host
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(owner, :attributes_config, [])
    else
      []
    end
  end
end
