defmodule ThreatShield.Accounts.Organisation do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias ThreatShield.Checks.OrganisationRole
  alias ThreatShield.DynamicAttribute

  @attributes [
    %DynamicAttribute{
      name: "Industry",
      description: "Examples of industry are financial services, health, IT."
    },
    %DynamicAttribute{
      name: "Legal Form",
      description: "Examples of legal form are LLC, Nonprofit, B Corps."
    },
    %DynamicAttribute{
      name: "Size",
      description: "Examples are small, medium and large.",
      sample_values: ["small", "medium", "large", "global"]
    },
    %DynamicAttribute{
      name: "Work from home regime",
      description: "Examples are fully remote, in-office and hybrid."
    }
  ]

  postgres do
    table "organisations"
    repo ThreatShield.Repo

    # match the columns of the Ecto migrations
    migration_types name: {:varchar, 255},
                    location: {:varchar, 255},
                    inserted_at: :naive_datetime,
                    updated_at: :naive_datetime

    migration_defaults inserted_at: "nil",
                       updated_at: "nil",
                       quotas: "%{ai_requests_per_month: 100}"
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
      description "The name of the organisation."
    end

    attribute :location, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
      description "The country where the organisation is located."
    end

    attribute :attributes, :map do
      allow_nil? false
      default %{}
      public? true

      description "Properties of the organisation such as industry, legal form, size and " <>
                    "work from home regime, as a map of names to texts."
    end

    attribute :quotas, :map do
      default %{ai_requests_per_month: 100}
      public? true
      description "The quotas of the organisation, e.g. the AI requests per month."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :users, ThreatShield.Accounts.User do
      through ThreatShield.Accounts.Membership
      source_attribute_on_join_resource :organisation_id
      destination_attribute_on_join_resource :user_id
    end

    has_many :memberships, ThreatShield.Accounts.Membership, public?: true
    has_many :systems, ThreatShield.ThreatManagement.System, public?: true
    has_many :threats, ThreatShield.ThreatManagement.Threat, public?: true
    has_many :assets, ThreatShield.ThreatManagement.Asset, public?: true
    has_many :invites, ThreatShield.Accounts.Invite, public?: true
  end

  aggregates do
    count :threat_count, :threats do
      public? true
      description "The number of threats of the organisation."
    end

    count :risk_count, [:threats, :risks] do
      public? true
      description "The number of risks of the organisation."
    end

    count :mitigation_count, [:threats, :risks, :mitigations] do
      public? true
      description "The number of mitigations of the organisation."
    end
  end

  validations do
    validate {ThreatShield.Validations.AttributeValues, attribute: :attributes}
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      description "Lists the organisations of which the actor is a member."
    end

    create :create do
      description "Creates an organisation. The actor becomes its first owner."
      accept [:name, :location, :attributes]
      change ThreatShield.Accounts.Changes.AddOwnerMembership
    end

    update :update do
      description "Changes the name, the location or the properties of an organisation."
      accept [:name, :location, :attributes]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if {OrganisationRole, right: :view_organisation, path: []}
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:update) do
      authorize_if {OrganisationRole, right: :edit_organisation, path: []}
    end

    policy action_type(:destroy) do
      authorize_if {OrganisationRole, right: :delete_organisation, path: []}
    end
  end

  def attributes_config do
    @attributes
  end

  def get_membership(%{memberships: memberships}, %{id: user_id}) when is_list(memberships) do
    Enum.find(memberships, fn m -> m.user_id == user_id end)
  end

  def get_membership(_, _), do: nil

  def list_system_options(%{systems: systems}) when is_list(systems) do
    [{"None", nil} | Enum.map(systems, fn s -> {s.name, s.id} end)]
  end

  def list_system_options(_), do: [{"None", nil}]

  def list_asset_options(%{assets: assets}) when is_list(assets) do
    [{"None", nil} | Enum.map(assets, fn a -> {a.name, a.id} end)]
  end

  def list_asset_options(_), do: [{"None", nil}]
end
