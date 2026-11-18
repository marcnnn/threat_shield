defmodule ThreatShield.ThreatManagement.Threat do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.ThreatManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @moduledoc """
  A threat is a potential danger to an organisation, a system or an asset.
  """

  alias ThreatShield.ThreatManagement.{Asset, System}
  alias ThreatShield.ThreatManagement.Validations.SameOrganisation

  postgres do
    table "threats"
    repo ThreatShield.Repo

    references do
      reference :organisation, on_delete: :delete
      # deleting a system deletes its threats, deleting an asset keeps them
      reference :system, on_delete: :delete
      reference :asset, on_delete: :nilify
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

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organisation, ThreatShield.Accounts.Organisation do
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :system, ThreatShield.ThreatManagement.System do
      allow_nil? true
      attribute_type :integer
    end

    belongs_to :asset, ThreatShield.ThreatManagement.Asset do
      allow_nil? true
      attribute_type :integer
    end

    has_many :risks, ThreatShield.ThreatManagement.Risk
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :system_id, :asset_id]

      argument :organisation_id, :integer, allow_nil?: false
      change set_attribute(:organisation_id, arg(:organisation_id))

      # a threat may only reference a system and an asset of its own organisation
      validate {SameOrganisation, attribute: :system_id, resource: System},
        where: [changing(:system_id)]

      validate {SameOrganisation, attribute: :asset_id, resource: Asset},
        where: [changing(:asset_id)]
    end

    update :update do
      accept [:name, :description, :system_id, :asset_id]
      require_atomic? false

      # a threat may only reference a system and an asset of its own organisation
      validate {SameOrganisation, attribute: :system_id, resource: System},
        where: [changing(:system_id)]

      validate {SameOrganisation, attribute: :asset_id, resource: Asset},
        where: [changing(:asset_id)]
    end

    read :for_user do
      argument :user_id, :integer, allow_nil?: false
      argument :roles, {:array, :atom}, allow_nil?: false

      filter expr(
               exists(
                 organisation.memberships,
                 user_id == ^arg(:user_id) and role in ^arg(:roles)
               )
             )
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(exists(organisation.memberships, user_id == ^actor(:id)))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(
                     exists(
                       organisation.memberships,
                       user_id == ^actor(:id) and role in [:owner, :editor]
                     )
                   )
    end
  end
end
