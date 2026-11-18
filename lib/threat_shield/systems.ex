defmodule ThreatShield.Systems do
  @moduledoc """
  The Systems context - delegates to Ash resources.
  """

  require Ash.Query

  alias ThreatShield.Access
  alias ThreatShield.Params
  alias ThreatShield.ThreatManagement.System
  alias ThreatShield.Accounts.{User, Organisation}

  def get_system!(%User{} = user, sys_id) do
    Access.get!(System, user, sys_id, nil,
      assets: [],
      threats: [],
      organisation: [:systems, :memberships]
    )
  end

  def list_systems(%User{} = user, %Organisation{id: org_id}) do
    System
    |> Access.query(user)
    |> Ash.Query.filter(organisation_id == ^org_id)
    |> Ash.Query.load([:assets, :threats])
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Creates a system. Returns `{:error, %Ash.Error.Invalid{}}` for invalid attributes.
  """
  def create_system(%User{} = user, %Organisation{id: org_id}, attrs \\ %{}) do
    organisation = Access.get!(Organisation, user, org_id, :create_system)

    System
    |> Ash.Changeset.for_create(:create, Params.put(attrs, :organisation_id, organisation.id),
      authorize?: false,
      skip_unknown_inputs: :*
    )
    |> Ash.create()
  end

  def update_system(%User{} = user, %System{id: sys_id}, attrs) do
    System
    |> Access.get!(user, sys_id, :edit_system)
    |> Ash.Changeset.for_update(:update, attrs, authorize?: false, skip_unknown_inputs: :*)
    |> Ash.update()
  end

  @doc """
  Deletes a system. The database deletes its assets and threats.
  """
  def delete_sys_by_id!(%User{} = user, id) do
    case Access.get(System, user, id, :delete_system) do
      {:ok, system} ->
        Ash.destroy!(system, authorize?: false)
        {1, [system]}

      {:error, :not_found} ->
        {0, []}
    end
  end

  def change_system(%System{} = system, attrs \\ %{}) do
    system
    |> Ecto.Changeset.cast(attrs, [:name, :description, :attributes])
    |> Ecto.Changeset.validate_required([:name, :description])
    |> Ecto.Changeset.validate_length(:name, max: 60)
    |> Ecto.Changeset.validate_length(:description, max: 4000)
    |> ThreatShield.DynamicAttribute.validate_values(:attributes)
  end
end
