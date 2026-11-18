defmodule ThreatShield.ThreatManagement.Risk do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.ThreatManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @moduledoc """
  A risk is a combination of a threat and an asset. It is the result of a risk assessment.
  """

  postgres do
    table "risks"
    repo ThreatShield.Repo

    references do
      reference :threat, on_delete: :delete
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 60
    end

    attribute :description, :string do
      allow_nil? false
      public? true
      constraints max_length: 4000
    end

    # an integer column
    attribute :estimated_cost, :integer do
      allow_nil? true
      public? true
      constraints min: 0, max: 2_147_483_647
    end

    attribute :probability, :float do
      allow_nil? true
      public? true
      constraints min: 0
    end

    attribute :severity, :float do
      allow_nil? true
      public? true
      constraints min: 0, max: 5
    end

    attribute :status, :atom do
      constraints one_of: [:identified, :assessed, :mitigated, :accepted]
      default :identified
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :threat, ThreatShield.ThreatManagement.Threat do
      allow_nil? false
      attribute_type :integer
    end

    has_many :mitigations, ThreatShield.ThreatManagement.Mitigation
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :estimated_cost, :probability, :severity, :status]

      argument :threat_id, :integer, allow_nil?: false
      change manage_relationship(:threat_id, :threat, type: :append_and_remove)
    end

    update :update do
      accept [:name, :description, :estimated_cost, :probability, :severity, :status]
    end

    read :for_user do
      argument :user_id, :integer, allow_nil?: false
      argument :roles, {:array, :atom}, allow_nil?: false

      filter expr(
               exists(
                 threat.organisation.memberships,
                 user_id == ^arg(:user_id) and role in ^arg(:roles)
               )
             )
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(exists(threat.organisation.memberships, user_id == ^actor(:id)))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(
                     exists(
                       threat.organisation.memberships,
                       user_id == ^actor(:id) and role in [:owner, :editor]
                     )
                   )
    end
  end

  def frequency_per_year(%{probability: probability}) do
    case probability do
      nil -> 0
      p -> p
    end
  end

  def severity(%{severity: severity}) do
    case severity do
      nil -> 0
      s -> s
    end
  end

  def estimated_risk_cost(%{estimated_cost: estimated_cost, probability: probability}),
    do: estimated_risk_cost(estimated_cost, probability)

  def estimated_risk_cost(estimated_cost, probability)
      when is_number(estimated_cost) and is_number(probability) do
    round(estimated_cost * probability)
  end

  def estimated_risk_cost(_estimated_cost, _probability), do: nil
end
