defmodule ThreatShield.Mitigations do
  @moduledoc """
  The Mitigations context - delegates to Ash resources.
  """

  require Ash.Query

  alias ThreatShield.Access
  alias ThreatShield.Params
  alias ThreatShield.ThreatManagement.{Mitigation, Risk}
  alias ThreatShield.Accounts.{User, Organisation}

  def get_mitigation!(%User{} = user, id) do
    Access.get!(Mitigation, user, id, nil,
      risk: [threat: [:system, organisation: [:memberships]]]
    )
  end

  def get_all_mitigations(%User{} = user, org_id) do
    Mitigation
    |> Access.query(user)
    |> Ash.Query.filter(risk.threat.organisation_id == ^org_id)
    |> Ash.Query.load([:risk])
    |> Ash.read!(authorize?: false)
  end

  def count_all_mitigations(%Organisation{id: org_id}) do
    Mitigation
    |> Ash.Query.filter(risk.threat.organisation_id == ^org_id)
    |> Ash.count!(authorize?: false)
  end

  @doc """
  Creates a mitigation for a risk. Returns `{:error, %Ash.Error.Invalid{}}` for
  invalid attributes.
  """
  def create_mitigation(%User{} = user, %Risk{id: risk_id}, attrs \\ %{}) do
    risk = Access.get!(Risk, user, risk_id, :create_mitigation)

    Mitigation
    |> Ash.Changeset.for_create(:create, Params.put(attrs, :risk_id, risk.id),
      authorize?: false,
      skip_unknown_inputs: :*
    )
    |> Ash.create()
  end

  @doc """
  Updates a mitigation. The risk of a mitigation cannot be changed.
  """
  def update_mitigation(%User{} = user, %Mitigation{id: mitigation_id}, attrs) do
    Mitigation
    |> Access.get!(user, mitigation_id, :edit_mitigation)
    |> Ash.Changeset.for_update(:update, attrs, authorize?: false, skip_unknown_inputs: :*)
    |> Ash.update()
  end

  @mitigation_fields ~w(name description issue_link status implementation_date implementation_notes verification_date verification_method verification_result)a

  def change_mitigation(%Mitigation{} = mitigation, attrs \\ %{}) do
    changeset =
      mitigation
      |> Ecto.Changeset.cast(attrs, @mitigation_fields)
      |> Ecto.Changeset.validate_required([:name, :description])
      |> Ecto.Changeset.validate_length(:name, max: 60)
      |> Ecto.Changeset.validate_length(:description, max: 4000)
      |> Ecto.Changeset.validate_length(:implementation_notes, max: 255)
      |> Ecto.Changeset.validate_length(:verification_method, max: 255)
      |> Ecto.Changeset.validate_length(:verification_result, max: 255)
      |> Ecto.Changeset.validate_length(:issue_link, max: 255)

    # Auto-update implementation status
    applied = Ecto.Changeset.apply_changes(changeset)
    implemented = applied.status in [:implemented, :verified]
    Ecto.Changeset.put_change(changeset, :is_implemented, implemented)
  end

  def delete_mitigation_by_id!(%User{} = user, id) do
    case Access.get(Mitigation, user, id, :delete_mitigation) do
      {:ok, mitigation} ->
        Ash.destroy!(mitigation, authorize?: false)
        {1, [mitigation]}

      {:error, :not_found} ->
        {0, []}
    end
  end
end
