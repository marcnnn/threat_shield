defmodule ThreatShield.Risks do
  @moduledoc """
  The Risks context - delegates to Ash resources.
  """

  require Ash.Query

  alias ThreatShield.Access
  alias ThreatShield.Params
  alias ThreatShield.ThreatManagement.{Risk, Threat}
  alias ThreatShield.Accounts.User

  def get_risk!(%User{} = user, risk_id) do
    Access.get!(Risk, user, risk_id, nil,
      mitigations: [],
      threat: [:system, organisation: [:systems, :memberships]]
    )
  end

  def get_all_risks(%User{} = user, org_id) do
    Risk
    |> Access.query(user)
    |> Ash.Query.filter(threat.organisation_id == ^org_id)
    |> Ash.Query.load(threat: :system)
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Creates a risk for a threat. Returns `{:error, %Ash.Error.Invalid{}}` for invalid
  attributes.
  """
  def create_risk(%User{} = user, threat_id, attrs \\ %{}) do
    threat = Access.get!(Threat, user, threat_id, :create_risk)

    Risk
    |> Ash.Changeset.for_create(:create, Params.put(attrs, :threat_id, threat.id),
      authorize?: false,
      skip_unknown_inputs: :*
    )
    |> Ash.create()
  end

  def update_risk(%User{} = user, %Risk{id: risk_id}, attrs) do
    Risk
    |> Access.get!(user, risk_id, :edit_risk)
    |> Ash.Changeset.for_update(:update, attrs, authorize?: false, skip_unknown_inputs: :*)
    |> Ash.update()
  end

  def delete_risk_by_id!(%User{} = user, id) do
    case Access.get(Risk, user, id, :delete_risk) do
      {:ok, risk} ->
        Ash.destroy!(risk, authorize?: false)
        {1, [risk]}

      {:error, :not_found} ->
        {0, []}
    end
  end

  def change_risk(%Risk{} = risk, attrs \\ %{}) do
    risk
    |> Ecto.Changeset.cast(attrs, [
      :name,
      :description,
      :estimated_cost,
      :probability,
      :severity,
      :status
    ])
    |> Ecto.Changeset.validate_required([:name, :description])
    |> Ecto.Changeset.validate_length(:name, max: 60)
    |> Ecto.Changeset.validate_length(:description, max: 4000)
  end
end
