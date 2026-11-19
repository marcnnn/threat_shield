defmodule ThreatShield.Accounts.Authorization do
  @moduledoc """
  The rights of an actor in an organisation, for the policies of the threat model
  library and of the accounts (`AshThreatShield.Authorization`, configured in
  `config/config.exs`). A user has a right in an organisation if their membership
  has a role with the right (see `ThreatShield.Accounts.Rights`).
  """
  @behaviour AshThreatShield.Authorization

  import Ash.Expr
  require Ash.Query

  alias ThreatShield.Accounts.{Membership, Rights}

  @impl true
  def filter(_actor, right) do
    roles = Rights.roles(right)
    expr(exists(memberships, user_id == ^actor(:id) and role in ^roles))
  end

  # The checks are the authorization, so they read without it.
  @impl true
  def authorized?(actor, organisation_id, right) do
    roles = Rights.roles(right)

    Membership
    |> Ash.Query.filter(
      user_id == ^actor.id and organisation_id == ^organisation_id and role in ^roles
    )
    # a lookup inside the policy check, see above
    |> Ash.exists?(authorize?: false)
  end

  @impl true
  def authorized_somewhere?(actor, right) do
    roles = Rights.roles(right)

    Membership
    |> Ash.Query.filter(user_id == ^actor.id and role in ^roles)
    # a lookup inside the policy check, see above
    |> Ash.exists?(authorize?: false)
  end
end
