defmodule ThreatShield.Accounts.Organisation do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :location, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
    end

    attribute :attributes, :map do
      allow_nil? true
      public? true
    end

    attribute :quotas, :map do
      default %{ai_requests_per_month: 100}
      public? true
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

    has_many :memberships, ThreatShield.Accounts.Membership
    has_many :systems, ThreatShield.ThreatManagement.System
    has_many :threats, ThreatShield.ThreatManagement.Threat
    has_many :assets, ThreatShield.ThreatManagement.Asset
    has_many :invites, ThreatShield.Accounts.Invite
  end

  validations do
    validate {ThreatShield.Validations.AttributeValues, attribute: :attributes}
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :location, :attributes]
    end

    update :update do
      accept [:name, :location, :attributes]
      require_atomic? false
    end

    read :for_user do
      argument :user_id, :integer, allow_nil?: false
      argument :roles, {:array, :atom}, allow_nil?: false

      filter expr(exists(memberships, user_id == ^arg(:user_id) and role in ^arg(:roles)))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:memberships, :user])
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type([:update, :destroy]) do
      authorize_if actor_attribute_equals(:__struct__, ThreatShield.Accounts.User)
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

  def describe(%{name: name, attributes: attributes, systems: systems}) do
    name_string = """
    The name of the organisation is "#{name}".
    """

    attribute_values =
      "The organisation has the following properties:\n" <>
        ((attributes || %{})
         |> Enum.filter(fn {_, val} -> val != "" end)
         |> Enum.map_join("\n", fn {key, val} -> ~s{"#{key}: ", "#{val}"} end))

    attribute_description =
      "The organisation properties have the following user-facing descriptions:\n" <>
        (@attributes
         |> Enum.map_join("\n", fn d -> ~s{"#{d.name}: ", "#{d.description}"} end))

    systems_list = if is_list(systems), do: systems, else: []

    system_description =
      "It has the following systems:\n" <>
        (systems_list
         |> Enum.map(fn sys -> ThreatShield.ThreatManagement.System.describe(sys) end)
         |> Enum.join("\n"))

    [name_string, attribute_values, attribute_description, system_description]
    |> Enum.join(" ")
  end
end
