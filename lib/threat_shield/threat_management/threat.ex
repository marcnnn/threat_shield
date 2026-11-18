defmodule ThreatShield.ThreatManagement.Threat do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.ThreatManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @moduledoc """
  A threat is a potential danger to an organisation, a system or an asset.
  """

  alias ThreatShield.Checks.{OrganisationRole, OrganisationRoleForCreate}
  alias ThreatShield.ThreatManagement.{Asset, System}
  alias ThreatShield.ThreatManagement.Validations.SameOrganisation

  # replaceable for another application, see "Extraction" in AGENTS.md
  @repo Application.compile_env(:threat_shield, :threat_management_repo, ThreatShield.Repo)

  postgres do
    table "threats"
    repo @repo

    # match the columns of the Ecto migrations
    migration_types name: {:varchar, 255},
                    description: {:varchar, 4000},
                    inserted_at: :naive_datetime,
                    updated_at: :naive_datetime

    migration_defaults inserted_at: "nil", updated_at: "nil"

    references do
      reference :organisation, on_delete: :delete, index?: true
      # deleting a system deletes its threats, deleting an asset keeps them
      reference :system, on_delete: :delete, index?: true
      reference :asset, on_delete: :nilify, index?: true
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 60
      description "The name of the threat."
    end

    # a nullable column; the validation below requires a value
    attribute :description, :string do
      allow_nil? true
      public? true
      constraints max_length: 4000
      description "The event or action that can compromise the organisation, system or asset."
    end

    attribute :organisation_id, :integer do
      allow_nil? false
      public? true
      description "The id of the organisation of the threat."
    end

    attribute :system_id, :integer do
      allow_nil? true
      public? true

      description "The id of the system that the threat concerns, if any. " <>
                    "The system must belong to the same organisation."
    end

    attribute :asset_id, :integer do
      allow_nil? true
      public? true

      description "The id of the asset that the threat concerns, if any. " <>
                    "The asset must belong to the same organisation."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organisation, ThreatShield.Accounts.Organisation do
      allow_nil? false
      attribute_type :integer
      public? true
      # declared in the attributes, with a description
      define_attribute? false
    end

    belongs_to :system, ThreatShield.ThreatManagement.System do
      allow_nil? true
      attribute_type :integer
      public? true
      # declared in the attributes, with a description
      define_attribute? false
    end

    belongs_to :asset, ThreatShield.ThreatManagement.Asset do
      allow_nil? true
      attribute_type :integer
      public? true
      # declared in the attributes, with a description
      define_attribute? false
    end

    has_many :risks, ThreatShield.ThreatManagement.Risk, public?: true
  end

  calculations do
    calculate :system_name, :string, expr(system.name) do
      public? true
      description "The name of the system of the threat."
    end

    calculate :asset_name, :string, expr(asset.name) do
      public? true
      description "The name of the asset of the threat."
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
      description "Lists the threats of the organisations of the actor."
    end

    read :for_organisation do
      description "Lists the threats of an organisation."

      argument :organisation_id, :integer do
        allow_nil? false
        description "The id of the organisation."
      end

      filter expr(organisation_id == ^arg(:organisation_id))
    end

    read :for_system do
      description "Lists the threats of a system."

      argument :system_id, :integer do
        allow_nil? false
        description "The id of the system."
      end

      filter expr(system_id == ^arg(:system_id))
    end

    read :for_asset do
      description "Lists the threats of an asset."

      argument :asset_id, :integer do
        allow_nil? false
        description "The id of the asset."
      end

      filter expr(asset_id == ^arg(:asset_id))
    end

    create :create do
      description "Creates a threat of an organisation, optionally of one of its systems " <>
                    "and assets."

      accept [:name, :description, :organisation_id, :system_id, :asset_id]

      # a threat may only reference a system and an asset of its own organisation
      validate {SameOrganisation, attribute: :system_id, resource: System},
        where: [changing(:system_id)]

      validate {SameOrganisation, attribute: :asset_id, resource: Asset},
        where: [changing(:asset_id)]
    end

    update :update do
      description "Changes a threat."
      accept [:name, :description, :system_id, :asset_id]
      # the validations read the system and the asset
      require_atomic? false

      validate {SameOrganisation, attribute: :system_id, resource: System},
        where: [changing(:system_id)]

      validate {SameOrganisation, attribute: :asset_id, resource: Asset},
        where: [changing(:asset_id)]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if {OrganisationRole, right: :view_organisation}
    end

    policy action_type(:create) do
      authorize_if {OrganisationRoleForCreate, right: :create_threat}
    end

    policy action_type(:update) do
      authorize_if {OrganisationRole, right: :edit_threat}
    end

    policy action_type(:destroy) do
      authorize_if {OrganisationRole, right: :delete_threat}
    end
  end
end
