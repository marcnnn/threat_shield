defmodule ThreatShield.Accounts.Changes.KeepsOwner do
  @moduledoc """
  An organisation keeps at least one owner and, with `members: true`, at least one
  member: the last owner cannot lose the role or leave, and the last member cannot
  leave.

  The check runs in the transaction of the action and locks the row of the
  organisation before it counts, so that two concurrent changes cannot each see
  another owner and together remove the last one.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Ash.Error.Changes.InvalidAttribute
  alias ThreatShield.Accounts.Organisation

  @impl true
  def change(changeset, opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      membership = changeset.data
      removed? = changeset.action_type == :destroy
      losing_owner? = membership.role == :owner and (removed? or changing_role?(changeset))
      leaving? = opts[:members] == true and removed?

      if losing_owner? or leaving? do
        organisation = lock_and_count(membership.organisation_id, context.actor)

        cond do
          leaving? and organisation.member_count <= 1 ->
            error(changeset, :user_id, "the last member cannot leave the organisation")

          losing_owner? and organisation.owner_count <= 1 ->
            error(changeset, :role, "the last owner must stay an owner")

          true ->
            changeset
        end
      else
        changeset
      end
    end)
  end

  defp changing_role?(changeset) do
    Ash.Changeset.changing_attribute?(changeset, :role) and
      Ash.Changeset.get_attribute(changeset, :role) != :owner
  end

  # The actor may change the membership, so it may also read the organisation and
  # count its members.
  defp lock_and_count(organisation_id, actor) do
    Organisation
    |> Ash.Query.filter(id == ^organisation_id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one!(actor: actor)
    |> Ash.load!([:member_count, :owner_count], actor: actor)
  end

  defp error(changeset, field, message) do
    Ash.Changeset.add_error(changeset, InvalidAttribute.exception(field: field, message: message))
  end
end
