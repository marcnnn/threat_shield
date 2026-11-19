defmodule ThreatShield.Accounts.Changes.AddOwnerMembership do
  @moduledoc """
  Makes the actor the first owner of a new organisation, in the transaction of the
  create action.
  """
  use Ash.Resource.Change

  alias ThreatShield.Accounts.Membership

  @impl true
  def change(changeset, _opts, %{actor: %{id: user_id}}) do
    Ash.Changeset.after_action(changeset, fn _changeset, organisation ->
      # Bootstrap: nobody may add members to an organisation without an owner, so
      # the first membership is created without authorization. The policy of the
      # create action has authorized the actor.
      Membership
      |> Ash.Changeset.for_create(
        :create,
        %{organisation_id: organisation.id, user_id: user_id, role: :owner},
        # bootstrap of the first owner, see above
        authorize?: false
      )
      |> Ash.create()
      |> case do
        {:ok, _membership} -> {:ok, organisation}
        {:error, error} -> {:error, error}
      end
    end)
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset, "an organisation is created by an actor, its first owner")
  end
end
