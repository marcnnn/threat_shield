defmodule ThreatShield.Threats do
  @moduledoc """
  The Threats context - delegates to Ash resources.
  """

  require Ash.Query

  alias ThreatShield.Access
  alias ThreatShield.Params
  alias ThreatShield.Scope
  alias ThreatShield.ThreatManagement.{Threat, System, Asset}
  alias ThreatShield.Accounts.{User, Organisation}

  def get_threat!(%User{} = user, threat_id) do
    Access.get!(Threat, user, threat_id, nil,
      system: [],
      asset: [],
      risks: :mitigations,
      organisation: [:systems, :assets, :memberships]
    )
  end

  def list_threats(%User{} = user, %Organisation{id: org_id}) do
    Threat
    |> Access.query(user)
    |> Ash.Query.filter(organisation_id == ^org_id)
    |> Ash.Query.load([:system, :asset, :risks])
    |> Ash.read!(authorize?: false)
  end

  def find_by_system(%User{} = user, %System{id: system_id, organisation_id: org_id}) do
    Threat
    |> Access.query(user)
    |> Ash.Query.filter(organisation_id == ^org_id and system_id == ^system_id)
    |> Ash.Query.load([:system, :asset])
    |> Ash.read!(authorize?: false)
  end

  def find_by_asset(%Asset{id: asset_id, organisation_id: org_id}) do
    Threat
    |> Ash.Query.filter(organisation_id == ^org_id and asset_id == ^asset_id)
    |> Ash.Query.load([:system, :asset])
    |> Ash.read!(authorize?: false)
  end

  def count_all_threats(%Organisation{id: org_id}) do
    Threat
    |> Ash.Query.filter(organisation_id == ^org_id)
    |> Ash.count!(authorize?: false)
  end

  @doc """
  Creates a threat. The system and the asset of the threat must belong to its
  organisation. Returns `{:error, %Ash.Error.Invalid{}}` for invalid attributes.
  """
  def create_threat(%User{} = user, %Organisation{id: org_id}, attrs \\ %{}) do
    organisation = Access.get!(Organisation, user, org_id, :create_threat)

    Threat
    |> Ash.Changeset.for_create(:create, Params.put(attrs, :organisation_id, organisation.id),
      authorize?: false,
      skip_unknown_inputs: :*
    )
    |> Ash.create()
  end

  @doc """
  Creates a threat with the given name and description for the scope: for its
  organisation and, if the scope has them, for its system and its asset.
  """
  def add_threat_with_name_and_description(%Scope{} = scope, name, description) do
    create_threat(scope.user, scope.organisation, %{
      name: name,
      description: description,
      system_id: scope.system && scope.system.id,
      asset_id: scope.asset && scope.asset.id
    })
  end

  def update_threat(%User{} = user, %Threat{id: threat_id}, attrs) do
    Threat
    |> Access.get!(user, threat_id, :edit_threat)
    |> Ash.Changeset.for_update(:update, attrs, authorize?: false, skip_unknown_inputs: :*)
    |> Ash.update()
  end

  def delete_threat_by_id(%User{} = user, threat_id) do
    case Access.get(Threat, user, threat_id, :delete_threat) do
      {:ok, threat} ->
        Ash.destroy!(threat, authorize?: false)
        {:ok, 1}

      {:error, :not_found} ->
        {:error, :unauthorized}
    end
  end

  def change_threat(%Threat{} = threat, attrs \\ %{}) do
    threat
    |> Ecto.Changeset.cast(attrs, [:name, :description, :system_id, :asset_id])
    |> Ecto.Changeset.validate_required([:name, :description])
    |> Ecto.Changeset.validate_length(:name, max: 60)
    |> Ecto.Changeset.validate_length(:description, max: 4000)
  end
end
