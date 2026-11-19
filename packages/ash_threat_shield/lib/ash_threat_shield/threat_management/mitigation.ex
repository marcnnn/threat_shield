defmodule AshThreatShield.ThreatManagement.Mitigation do
  @moduledoc """
  A mitigation is a measure that reduces a risk.
  """
  use Ash.Resource,
    otp_app: :ash_threat_shield,
    domain: AshThreatShield.ThreatManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias AshThreatShield.Checks.{OrganisationRole, OrganisationRoleForCreate}
  alias AshThreatShield.ThreatManagement.Risk

  # configured by the host application, see the README
  @repo Application.compile_env!(:ash_threat_shield, :repo)

  postgres do
    table "mitigations"
    repo @repo

    # match the columns of the Ecto migrations
    migration_types name: {:varchar, 255},
                    description: {:varchar, 4000},
                    issue_link: {:varchar, 255},
                    status: {:varchar, 255},
                    implementation_notes: {:varchar, 255},
                    verification_method: {:varchar, 255},
                    verification_result: {:varchar, 255},
                    inserted_at: :naive_datetime,
                    updated_at: :naive_datetime

    migration_defaults inserted_at: "nil", updated_at: "nil"

    references do
      reference :risk, on_delete: :delete, index?: true
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 60
      description "The name of the mitigation."
    end

    # a nullable column; the validation below requires a value
    attribute :description, :string do
      allow_nil? true
      public? true
      constraints max_length: 4000
      description "The measure and how it reduces the risk."
    end

    attribute :issue_link, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
      description "A link to the issue that tracks the implementation."
    end

    # a nullable column with a default; the validation below requires a value
    attribute :status, AshThreatShield.ThreatManagement.MitigationStatus do
      allow_nil? true
      default :open
      public? true
      description "The status of the mitigation."
    end

    attribute :implementation_date, :date do
      allow_nil? true
      public? true
      description "The date of the implementation."
    end

    attribute :implementation_notes, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
      description "Notes on the implementation."
    end

    attribute :is_implemented, :boolean do
      allow_nil? false
      default false
      public? true
      writable? false
      description "Whether the mitigation is implemented. It follows from the status."
    end

    attribute :verification_date, :date do
      allow_nil? true
      public? true
      description "The date of the verification."
    end

    attribute :verification_method, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
      description "How the effect of the mitigation is verified."
    end

    attribute :verification_result, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
      description "The result of the verification."
    end

    attribute :risk_id, :integer do
      allow_nil? false
      public? true
      description "The id of the risk that the mitigation reduces."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :risk, AshThreatShield.ThreatManagement.Risk do
      allow_nil? false
      attribute_type :integer
      public? true
      # declared in the attributes, with a description
      define_attribute? false
    end
  end

  calculations do
    calculate :organisation_id, :integer, expr(risk.threat.organisation_id) do
      public? true
      description "The id of the organisation of the mitigation."
    end

    calculate :risk_name, :string, expr(risk.name) do
      public? true
      description "The name of the risk of the mitigation."
    end
  end

  validations do
    # only when the description is valid otherwise, e.g. not too long
    validate present(:description), message: "is required", only_when_valid?: true
    # is_implemented follows from the status
    validate present(:status), message: "is required"
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      description "Lists the mitigations of the organisations of the actor."
    end

    read :for_organisation do
      description "Lists the mitigations of an organisation."

      argument :organisation_id, :integer do
        allow_nil? false
        description "The id of the organisation."
      end

      filter expr(risk.threat.organisation_id == ^arg(:organisation_id))
    end

    create :create do
      description "Creates a mitigation of a risk."

      accept [
        :name,
        :description,
        :issue_link,
        :status,
        :implementation_date,
        :implementation_notes,
        :verification_date,
        :verification_method,
        :verification_result,
        :risk_id
      ]

      change AshThreatShield.ThreatManagement.Changes.SetImplemented
    end

    update :update do
      description "Changes a mitigation. It stays with its risk."

      accept [
        :name,
        :description,
        :issue_link,
        :status,
        :implementation_date,
        :implementation_notes,
        :verification_date,
        :verification_method,
        :verification_result
      ]

      change AshThreatShield.ThreatManagement.Changes.SetImplemented
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if {OrganisationRole,
                    right: :view_organisation, path: [:risk, :threat, :organisation]}
    end

    policy action_type(:create) do
      authorize_if {OrganisationRoleForCreate,
                    right: :create_mitigation, parent: {:risk_id, Risk}}
    end

    policy action_type(:update) do
      authorize_if {OrganisationRole,
                    right: :edit_mitigation, path: [:risk, :threat, :organisation]}
    end

    policy action_type(:destroy) do
      authorize_if {OrganisationRole,
                    right: :delete_mitigation, path: [:risk, :threat, :organisation]}
    end
  end
end
