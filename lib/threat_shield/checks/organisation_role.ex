defmodule ThreatShield.Checks.OrganisationRole do
  @moduledoc """
  Authorizes if the actor is a member of the record's organisation with a role that
  has the given right (see `ThreatShield.Accounts.Rights`).

  It is a filter check: reads return only the records of the actor's organisations,
  and updates and destroys of other records fail.

  Options:

    * `:right` - the right, required
    * `:path` - the relationships from the record to its organisation, default
      `[:organisation]`; `[]` for the organisation itself

  For create actions, use `ThreatShield.Checks.OrganisationRoleForCreate`: a new
  record has no relationships yet.
  """
  use Ash.Policy.FilterCheck

  alias ThreatShield.Accounts.Rights

  @impl true
  def describe(opts) do
    "actor has the right #{inspect(opts[:right])} in the organisation of the record"
  end

  @impl true
  def filter(_actor, _context, opts) do
    roles = Rights.roles(Keyword.fetch!(opts, :right))
    path = Keyword.get(opts, :path, [:organisation]) ++ [:memberships]

    Ash.Query.Exists.new(path, expr(user_id == ^actor(:id) and role in ^roles))
  end
end
