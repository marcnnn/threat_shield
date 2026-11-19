defmodule AshThreatShield.ThreatManagement.Risk do
  @moduledoc """
  A risk is a potential negative outcome of a threat: loss, damage, or harm. It is the
  result of a risk assessment.
  """
  use Ash.Resource,
    otp_app: :ash_threat_shield,
    domain: AshThreatShield.ThreatManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias AshThreatShield.Checks.{OrganisationRole, OrganisationRoleForCreate}
  alias AshThreatShield.ThreatManagement.Threat

  # configured by the host application, see the README
  @repo Application.compile_env!(:ash_threat_shield, :repo)

  postgres do
    table "risks"
    repo @repo

    # match the columns of the Ecto migrations
    migration_types name: {:varchar, 255},
                    description: {:varchar, 4000},
                    estimated_cost: :integer,
                    status: {:varchar, 255},
                    inserted_at: :naive_datetime,
                    updated_at: :naive_datetime

    migration_defaults inserted_at: "nil", updated_at: "nil"

    references do
      reference :threat, on_delete: :delete, index?: true
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 60
      description "The name of the risk."
    end

    # a nullable column; the validation below requires a value
    attribute :description, :string do
      allow_nil? true
      public? true
      constraints max_length: 4000
      description "The loss, damage or harm that the threat can cause."
    end

    attribute :estimated_cost, :integer do
      allow_nil? true
      public? true
      constraints min: 0, max: 2_147_483_647
      description "The estimated cost of one incident in EUR."
    end

    attribute :probability, :float do
      allow_nil? true
      public? true
      constraints min: 0
      description "The expected number of incidents per year."
    end

    attribute :severity, :float do
      allow_nil? true
      public? true
      constraints min: 0, max: 5
      description "The severity of an incident, from 0 to 5."
    end

    attribute :status, AshThreatShield.ThreatManagement.RiskStatus do
      allow_nil? true
      default :identified
      public? true
      description "The status of the risk."
    end

    attribute :threat_id, :integer do
      allow_nil? false
      public? true
      description "The id of the threat of the risk."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :threat, AshThreatShield.ThreatManagement.Threat do
      allow_nil? false
      attribute_type :integer
      public? true
      # declared in the attributes, with a description
      define_attribute? false
    end

    has_many :mitigations, AshThreatShield.ThreatManagement.Mitigation, public?: true
  end

  calculations do
    calculate :organisation_id, :integer, expr(threat.organisation_id) do
      allow_nil? false
      public? true
      description "The id of the organisation of the risk."
    end

    calculate :estimated_risk_cost,
              :integer,
              expr(
                if is_nil(estimated_cost) or is_nil(probability) do
                  nil
                else
                  fragment("round(?)", estimated_cost * probability)
                end
              ) do
      allow_nil? true
      public? true

      description "The estimated cost per year in EUR: the cost of an incident times the " <>
                    "number of incidents per year."
    end

    calculate :threat_name, :string, expr(threat.name) do
      allow_nil? false
      public? true
      description "The name of the threat of the risk."
    end
  end

  validations do
    # only when the description is valid otherwise, e.g. not too long
    validate present(:description), message: "is required", only_when_valid?: true
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      description "Lists the risks of the organisations of the actor."
    end

    read :for_organisation do
      description "Lists the risks of an organisation."

      argument :organisation_id, :integer do
        allow_nil? false
        description "The id of the organisation."
      end

      filter expr(threat.organisation_id == ^arg(:organisation_id))
    end

    create :create do
      description "Creates a risk of a threat."
      accept [:name, :description, :estimated_cost, :probability, :severity, :status, :threat_id]
    end

    update :update do
      description "Changes a risk."
      accept [:name, :description, :estimated_cost, :probability, :severity, :status]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if {OrganisationRole, right: :view_organisation, path: [:threat, :organisation]}
    end

    policy action_type(:create) do
      authorize_if {OrganisationRoleForCreate, right: :create_risk, parent: {:threat_id, Threat}}
    end

    policy action_type(:update) do
      authorize_if {OrganisationRole, right: :edit_risk, path: [:threat, :organisation]}
    end

    policy action_type(:destroy) do
      authorize_if {OrganisationRole, right: :delete_risk, path: [:threat, :organisation]}
    end
  end

  @doc """
  The number of incidents per year, 0 if it is not estimated.
  """
  def frequency_per_year(%{probability: probability}), do: probability || 0

  @doc """
  The severity, 0 if it is not estimated.
  """
  def severity(%{severity: severity}), do: severity || 0
end
