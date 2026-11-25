defmodule AshThreatShield.ThreatManagement.Asset do
  @moduledoc """
  An asset is a valuable resource or data of an organisation, optionally of one of
  its systems. Deleting an asset keeps its threats.
  """
  use Ash.Resource,
    otp_app: :ash_threat_shield,
    domain: AshThreatShield.ThreatManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias AshThreatShield.Checks.{OrganisationRole, OrganisationRoleForCreate}
  alias AshThreatShield.ThreatManagement.Changes.OverallCriticality
  alias AshThreatShield.ThreatManagement.Validations.SameOrganisation

  # configured by the host application, see the README
  @repo Application.compile_env!(:ash_threat_shield, :repo)
  @owner Application.compile_env!(:ash_threat_shield, :owner_resource)

  postgres do
    table "assets"
    repo @repo

    # match the columns of the Ecto migrations
    migration_types name: {:varchar, 255},
                    description: {:varchar, 4000},
                    inserted_at: :naive_datetime,
                    updated_at: :naive_datetime

    migration_defaults inserted_at: "nil", updated_at: "nil"

    references do
      reference :organisation, on_delete: :delete, index?: true
      # deleting a system deletes its assets
      reference :system, on_delete: :delete, index?: true
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 60
      description "The name of the asset."
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints max_length: 4000
      description "What the asset is and why it is valuable."
    end

    attribute :criticality_loss, :float do
      allow_nil? true
      public? true
      constraints min: 0, max: 5
      description "How critical a loss of the asset is, from 0 to 5."
    end

    attribute :criticality_theft, :float do
      allow_nil? true
      public? true
      constraints min: 0, max: 5
      description "How critical a theft of the asset is, from 0 to 5."
    end

    attribute :criticality_publication, :float do
      allow_nil? true
      public? true
      constraints min: 0, max: 5
      description "How critical a publication of the asset is, from 0 to 5."
    end

    attribute :criticality_overall, :float do
      allow_nil? true
      public? true
      constraints min: 0, max: 5

      description "The overall criticality, from 0 to 5. It is at least the average of " <>
                    "the other three criticalities."
    end

    attribute :organisation_id, :integer do
      allow_nil? false
      public? true
      description "The id of the organisation of the asset."
    end

    attribute :system_id, :integer do
      allow_nil? true
      public? true

      description "The id of the system of the asset, if it belongs to one. " <>
                    "The system must belong to the same organisation."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organisation, @owner do
      allow_nil? false
      attribute_type :integer
      public? true
      # declared in the attributes, with a description
      define_attribute? false
    end

    belongs_to :system, AshThreatShield.ThreatManagement.System do
      allow_nil? true
      attribute_type :integer
      public? true
      # declared in the attributes, with a description
      define_attribute? false
    end

    has_many :threats, AshThreatShield.ThreatManagement.Threat, public?: true
  end

  calculations do
    calculate :system_name, :string, expr(system.name) do
      allow_nil? true
      public? true
      description "The name of the system of the asset."
    end
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      description "Lists the assets of the organisations of the actor."
    end

    read :for_organisation do
      description "Lists the assets of an organisation."

      argument :organisation_id, :integer do
        allow_nil? false
        description "The id of the organisation."
      end

      filter expr(organisation_id == ^arg(:organisation_id))
    end

    read :for_system do
      description "Lists the assets of a system."

      argument :system_id, :integer do
        allow_nil? false
        description "The id of the system."
      end

      filter expr(system_id == ^arg(:system_id))
    end

    create :create do
      description "Creates an asset of an organisation, optionally of one of its systems."

      accept [
        :name,
        :description,
        :organisation_id,
        :system_id,
        :criticality_loss,
        :criticality_theft,
        :criticality_publication,
        :criticality_overall
      ]

      # an asset may only belong to a system of its own organisation
      validate {SameOrganisation,
                attribute: :system_id, resource: AshThreatShield.ThreatManagement.System},
               where: [changing(:system_id)]

      change OverallCriticality
    end

    update :update do
      description "Changes an asset."

      accept [
        :name,
        :description,
        :system_id,
        :criticality_loss,
        :criticality_theft,
        :criticality_publication,
        :criticality_overall
      ]

      # the validation reads the system
      require_atomic? false

      validate {SameOrganisation,
                attribute: :system_id, resource: AshThreatShield.ThreatManagement.System},
               where: [changing(:system_id)]

      change OverallCriticality
    end
  end

  validations do
    # like the other entities, an asset needs a description (the column is nullable);
    # only when the description is valid otherwise, e.g. not too long
    validate present(:description), message: "is required", only_when_valid?: true
  end

  policies do
    policy action_type(:read) do
      authorize_if {OrganisationRole, right: :view_organisation}
    end

    policy action_type(:create) do
      authorize_if {OrganisationRoleForCreate, right: :create_asset}
    end

    policy action_type(:update) do
      authorize_if {OrganisationRole, right: :edit_asset}
    end

    policy action_type(:destroy) do
      authorize_if {OrganisationRole, right: :delete_asset}
    end
  end
end
