defmodule ThreatShield.Assets do
  @moduledoc """
  The Assets context - delegates to Ash resources.
  """

  require Ash.Query

  alias ThreatShield.Access
  alias ThreatShield.Params
  alias ThreatShield.Scope
  alias ThreatShield.ThreatManagement.{Asset, System}
  alias ThreatShield.Accounts.{User, Organisation}

  def get_asset!(%User{} = user, asset_id) do
    Access.get!(Asset, user, asset_id, nil,
      system: [],
      threats: [],
      organisation: [:systems, :assets, :memberships]
    )
  end

  def list_assets(%User{} = user, %Organisation{id: org_id}) do
    Asset
    |> Access.query(user)
    |> Ash.Query.filter(organisation_id == ^org_id)
    |> Ash.Query.load([:threats])
    |> Ash.read!(authorize?: false)
  end

  def find_by_system(%User{} = user, %System{id: system_id, organisation_id: org_id}) do
    Asset
    |> Access.query(user)
    |> Ash.Query.filter(organisation_id == ^org_id and system_id == ^system_id)
    |> Ash.Query.load([:threats])
    |> Ash.read!(authorize?: false)
  end

  def prepare_asset(system_id \\ nil) do
    %Asset{
      system_id: system_id,
      criticality_loss: 0.0,
      criticality_theft: 0.0,
      criticality_publication: 0.0,
      criticality_overall: 0.0
    }
  end

  def change_asset(%Asset{} = asset, attrs \\ %{}) do
    changeset =
      asset
      |> Ecto.Changeset.cast(attrs, [
        :name,
        :description,
        :system_id,
        :criticality_loss,
        :criticality_theft,
        :criticality_publication,
        :criticality_overall
      ])
      |> Ecto.Changeset.validate_required([:name])
      |> Ecto.Changeset.validate_length(:name, max: 60)
      |> Ecto.Changeset.validate_length(:description, max: 4000)

    # Auto-calculate overall criticality
    applied = Ecto.Changeset.apply_changes(changeset)
    crit = Asset.calc_overall_criticality(applied)
    Ecto.Changeset.put_change(changeset, :criticality_overall, crit)
  end

  @doc """
  Creates an asset. Returns `{:error, %Ash.Error.Invalid{}}` for invalid attributes.
  """
  def create_asset(%User{} = user, %Organisation{id: org_id}, attrs \\ %{}) do
    organisation = Access.get!(Organisation, user, org_id, :create_asset)

    Asset
    |> Ash.Changeset.for_create(:create, Params.put(attrs, :organisation_id, organisation.id),
      authorize?: false,
      skip_unknown_inputs: :*
    )
    |> Ash.create(load: [:system])
  end

  def update_asset(%User{} = user, %Asset{id: asset_id}, attrs) do
    Asset
    |> Access.get!(user, asset_id, :edit_asset)
    |> Ash.Changeset.for_update(:update, attrs, authorize?: false, skip_unknown_inputs: :*)
    |> Ash.update(load: [:system])
  end

  @doc """
  Creates an asset with the given name and description for the scope: for its
  organisation and, if the scope has one, for its system.
  """
  def add_asset_with_name_and_description(%Scope{} = scope, name, description) do
    create_asset(scope.user, scope.organisation, %{
      name: name,
      description: description,
      system_id: scope.system && scope.system.id
    })
  end

  @doc """
  Deletes an asset. The database keeps its threats and removes their reference.
  """
  def delete_asset_by_id(%User{} = user, asset_id) do
    case Access.get(Asset, user, asset_id, :delete_asset) do
      {:ok, asset} ->
        Ash.destroy!(asset, authorize?: false)
        {1, [asset]}

      {:error, :not_found} ->
        {0, []}
    end
  end
end
