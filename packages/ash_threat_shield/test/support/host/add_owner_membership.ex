defmodule AshThreatShield.Test.AddOwnerMembership do
  @moduledoc """
  Makes the actor the owner of a new organisation of the test host.
  """
  use Ash.Resource.Change

  alias AshThreatShield.Test.Accounts

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, organisation ->
      Accounts.create_membership!(
        %{role: :owner, user_id: context.actor.id, organisation_id: organisation.id},
        # bootstrap of the first owner: nobody may add members without one
        authorize?: false
      )

      {:ok, organisation}
    end)
  end
end
