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
  alias Ash.Error.Query.NotFound
  alias ThreatShield.Accounts.Organisation

  @impl true
  def change(changeset, opts, context) do
    Ash.Changeset.before_action(changeset, &check(&1, opts[:members] == true, context.actor))
  end

  defp check(changeset, members?, actor) do
    membership = changeset.data
    removed? = changeset.action_type == :destroy
    losing_owner? = membership.role == :owner and (removed? or changing_role?(changeset))
    leaving? = members? and removed?

    if losing_owner? or leaving? do
      case lock_and_count(membership.organisation_id, actor) do
        {:ok, organisation} -> check_counts(changeset, organisation, losing_owner?, leaving?)
        {:error, error} -> Ash.Changeset.add_error(changeset, error)
      end
    else
      changeset
    end
  end

  defp check_counts(changeset, organisation, losing_owner?, leaving?) do
    cond do
      leaving? and organisation.member_count <= 1 ->
        error(changeset, :user_id, "the last member cannot leave the organisation")

      losing_owner? and organisation.owner_count <= 1 ->
        error(changeset, :role, "the last owner must stay an owner")

      true ->
        changeset
    end
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
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, %Organisation{} = organisation} ->
        Ash.load(organisation, [:member_count, :owner_count], actor: actor)

      {:ok, nil} ->
        {:error, NotFound.exception(resource: Organisation)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp error(changeset, field, message) do
    Ash.Changeset.add_error(changeset, InvalidAttribute.exception(field: field, message: message))
  end
end
