defmodule AshThreatShield.Test.Authorization do
  @moduledoc """
  The `AshThreatShield.Authorization` of the test host: owners and editors have all
  rights, viewers only `:view_organisation`.
  """
  @behaviour AshThreatShield.Authorization

  import Ash.Expr
  require Ash.Query

  alias AshThreatShield.Test.Membership

  @impl true
  def filter(_actor, right) do
    roles = roles(right)
    expr(exists(memberships, user_id == ^actor(:id) and role in ^roles))
  end

  # The checks are the authorization, so they read without it.
  @impl true
  def authorized?(actor, organisation_id, right) do
    roles = roles(right)

    Membership
    |> Ash.Query.filter(
      user_id == ^actor.id and organisation_id == ^organisation_id and role in ^roles
    )
    |> Ash.exists?(authorize?: false)
  end

  @impl true
  def authorized_somewhere?(actor, right) do
    roles = roles(right)

    Membership
    |> Ash.Query.filter(user_id == ^actor.id and role in ^roles)
    |> Ash.exists?(authorize?: false)
  end

  defp roles(:view_organisation), do: [:owner, :editor, :viewer]

  defp roles(right) do
    if right in AshThreatShield.Authorization.rights() do
      [:owner, :editor]
    else
      raise ArgumentError, "unknown right #{inspect(right)}"
    end
  end
end
