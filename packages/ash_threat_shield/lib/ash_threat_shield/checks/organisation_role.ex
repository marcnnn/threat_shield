defmodule AshThreatShield.Checks.OrganisationRole do
  @moduledoc """
  Authorizes if the actor has the given right in the record's organisation. The
  configured `AshThreatShield.Authorization` decides the rights.

  It is a filter check: reads return only the records of the actor's organisations,
  and updates and destroys of other records fail.

  Options:

    * `:right` - the right, required
    * `:path` - the relationships from the record to its organisation, default
      `[:organisation]`; `[]` for the organisation itself

  For create actions, use `AshThreatShield.Checks.OrganisationRoleForCreate`: a new
  record has no relationships yet.
  """
  use Ash.Policy.FilterCheck

  alias Ash.Query.Exists
  alias AshThreatShield.Authorization

  @impl true
  def describe(opts) do
    "actor has the right #{inspect(opts[:right])} in the organisation of the record"
  end

  @impl true
  def filter(actor, _context, opts) do
    organisation_filter = Authorization.configured().filter(actor, Keyword.fetch!(opts, :right))

    case Keyword.get(opts, :path, [:organisation]) do
      [] -> organisation_filter
      path -> Exists.new(path, organisation_filter)
    end
  end
end
