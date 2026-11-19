defmodule AshThreatShield.Authorization do
  @moduledoc """
  Decides which rights an actor has in an organisation. The host application
  implements this behaviour and configures it:

      config :ash_threat_shield, :authorization, MyApp.ThreatModelAuthorization

  The policies of the library resources use it through
  `AshThreatShield.Checks.OrganisationRole` (reads, updates, destroys) and
  `AshThreatShield.Checks.OrganisationRoleForCreate` (creates and suggestions).

  The library asks for these rights (`t:right/0`): `:view_organisation`, and
  `:create_*`, `:edit_*` and `:delete_*` of `system`, `asset`, `threat`, `risk` and
  `mitigation`. A host may use the checks with further rights for its own resources.
  """

  @typedoc "A right, e.g. `:create_threat`."
  @type right :: atom()

  @doc """
  An expression on the owner resource that is true for the organisations in which
  the actor has the right, e.g.

      expr(exists(memberships, user_id == ^actor(:id) and role in ^roles))

  The checks use it as a filter, so reads return only the records of these
  organisations. The actor may be `nil`.
  """
  @callback filter(actor :: term(), right()) :: Ash.Expr.t()

  @doc """
  Whether the actor has the right in the organisation with the id. The actor is not
  `nil`. The check calls it to authorize a create, so read without authorization.
  """
  @callback authorized?(actor :: term(), organisation_id :: term(), right()) :: boolean()

  @doc """
  Whether the actor has the right in any organisation. ash_ai lists an MCP tool of a
  create action only for such an actor (see
  `AshThreatShield.Checks.OrganisationRoleForCreate`).
  """
  @callback authorized_somewhere?(actor :: term(), right()) :: boolean()

  @doc """
  The rights that the library asks for.
  """
  @spec rights() :: [right()]
  def rights do
    [
      :view_organisation,
      :create_system,
      :create_asset,
      :create_threat,
      :create_risk,
      :create_mitigation,
      :edit_system,
      :edit_asset,
      :edit_threat,
      :edit_risk,
      :edit_mitigation,
      :delete_system,
      :delete_asset,
      :delete_threat,
      :delete_risk,
      :delete_mitigation
    ]
  end

  @doc """
  The configured implementation. Raises if there is none.
  """
  @spec configured() :: module()
  def configured, do: Application.fetch_env!(:ash_threat_shield, :authorization)
end
