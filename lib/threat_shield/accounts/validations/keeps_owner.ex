defmodule ThreatShield.Accounts.Validations.KeepsOwner do
  @moduledoc """
  An organisation keeps at least one owner and, with `members: true`, at least one
  member: the last owner cannot lose the role or leave, and the last member cannot
  leave.
  """
  use Ash.Resource.Validation

  require Ash.Query

  alias ThreatShield.Accounts.Membership

  @impl true
  def validate(changeset, opts, context) do
    actor = context.actor
    membership = changeset.data
    removed? = changeset.action_type == :destroy
    losing_owner? = membership.role == :owner and (removed? or changing_role?(changeset))

    cond do
      opts[:members] && removed? && count(membership, nil, actor) <= 1 ->
        {:error, field: :user_id, message: "the last member cannot leave the organisation"}

      losing_owner? && count(membership, :owner, actor) <= 1 ->
        {:error, field: :role, message: "the last owner must stay an owner"}

      true ->
        :ok
    end
  end

  defp changing_role?(changeset) do
    Ash.Changeset.changing_attribute?(changeset, :role) and
      Ash.Changeset.get_attribute(changeset, :role) != :owner
  end

  defp count(%Membership{organisation_id: org_id}, nil, actor) do
    Membership
    |> Ash.Query.filter(organisation_id == ^org_id)
    |> Ash.count!(actor: actor)
  end

  defp count(%Membership{organisation_id: org_id}, role, actor) do
    Membership
    |> Ash.Query.filter(organisation_id == ^org_id and role == ^role)
    |> Ash.count!(actor: actor)
  end
end
