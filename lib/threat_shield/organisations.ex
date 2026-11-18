defmodule ThreatShield.Organisations do
  @moduledoc """
  The Organisations context - delegates to Ash resources.
  """

  alias ThreatShield.Access
  alias ThreatShield.Accounts.{User, Organisation, Membership}

  @doc """
  Returns the list of organisations, where the user is a member of.
  """
  def list_organisations(%User{} = user) do
    Organisation
    |> Access.query(user)
    |> Ash.read!(authorize?: false)
  end

  def list_organisations(_), do: []

  @doc """
  Returns all organisations for a platform admin.
  """
  def list_all_organisations(%User{global_roles: roles} = _admin) do
    if "platform_admin" in (roles || []) do
      Ash.read!(Organisation, authorize?: false)
    else
      {:error, :not_allowed}
    end
  end

  def get_organisation!(%User{} = user, org_id) do
    Access.get!(Organisation, user, org_id, nil,
      memberships: :user,
      systems: [],
      threats: [:system, :asset],
      assets: [:system]
    )
  end

  def create_organisation(attrs \\ %{}, %User{} = current_user) do
    Ash.transaction([Organisation, Membership], fn ->
      with {:ok, organisation} <-
             Organisation
             |> Ash.Changeset.for_create(:create, attrs,
               authorize?: false,
               skip_unknown_inputs: :*
             )
             |> Ash.create(),
           {:ok, _membership} <-
             Membership
             |> Ash.Changeset.for_create(
               :create,
               %{user_id: current_user.id, organisation_id: organisation.id, role: :owner},
               authorize?: false
             )
             |> Ash.create() do
        organisation
      else
        {:error, error} -> Ash.DataLayer.rollback([Organisation, Membership], error)
      end
    end)
  end

  def update_organisation(%Organisation{id: org_id}, %User{} = user, attrs) do
    Organisation
    |> Access.get!(user, org_id, :edit_organisation)
    |> Ash.Changeset.for_update(:update, attrs, authorize?: false, skip_unknown_inputs: :*)
    |> Ash.update()
  end

  def change_organisation(%Organisation{} = organisation, attrs \\ %{}) do
    organisation
    |> Ecto.Changeset.cast(attrs, [:name, :location, :attributes])
    |> Ecto.Changeset.validate_required([:name])
    |> Ecto.Changeset.validate_length(:name, max: 255)
    |> Ecto.Changeset.validate_length(:location, max: 255)
    |> ThreatShield.DynamicAttribute.validate_values(:attributes)
  end

  def delete_org_by_id!(%User{} = user, id) do
    case Access.get(Organisation, user, id, :delete_organisation) do
      {:ok, organisation} ->
        Ash.destroy!(organisation, authorize?: false)
        {1, [organisation]}

      {:error, :not_found} ->
        {0, []}
    end
  end
end
