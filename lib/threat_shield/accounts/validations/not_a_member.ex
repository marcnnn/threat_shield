defmodule ThreatShield.Accounts.Validations.NotAMember do
  @moduledoc """
  Validates that the invited email address does not belong to a member of the
  organisation already.

      validate ThreatShield.Accounts.Validations.NotAMember
  """
  use Ash.Resource.Validation

  require Ash.Query

  alias ThreatShield.Accounts.Membership

  @impl true
  def validate(changeset, _opts, _context) do
    email = Ash.Changeset.get_attribute(changeset, :email)
    org_id = Ash.Changeset.get_attribute(changeset, :organisation_id)

    if is_nil(email) or is_nil(org_id) do
      :ok
    else
      # Only checks whether the address is taken; the create policy checks the actor,
      # and the result reveals nothing the inviting member cannot see on the members page.
      member? =
        Membership
        |> Ash.Query.filter(organisation_id == ^org_id and user.email == ^email)
        # a lookup inside a validation; the create policy authorizes the actor
        |> Ash.exists?(authorize?: false)

      if member? do
        {:error, field: :email, message: "is already a member of this organisation"}
      else
        :ok
      end
    end
  end
end
