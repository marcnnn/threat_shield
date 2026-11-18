defmodule ThreatShield.ThreatManagement.System do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.ThreatManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias ThreatShield.DynamicAttribute

  @attributes [
    %DynamicAttribute{
      name: "Application type",
      description:
        "Examples of application types are online-shops, information systems, web applications, etc."
    },
    %DynamicAttribute{
      name: "Audience",
      description: "Examples of audiences are customers, employees, partners, etc."
    },
    %DynamicAttribute{
      name: "Application Framework",
      description: "Examples of application frameworks are Django, Ruby on Rails, Flutter."
    },
    %DynamicAttribute{
      name: "Database",
      description: "Examples of databases are Postgres, MySQL, Neo4j."
    },
    %DynamicAttribute{
      name: "Security frameworks",
      description:
        "Examples of authentication frameworks are Passport.js, Okta, Keycloak, Spring Security."
    },
    %DynamicAttribute{
      name: "Infrastructure",
      description:
        "Examples of infrastructure are AWS, Azure, GCP, Kubernetes, On-Premise, Windows Server, etc."
    }
  ]

  postgres do
    table "systems"
    repo ThreatShield.Repo

    identity_index_names unique_name_per_organisation: "systems_organisation_id_name_index"

    references do
      reference :organisation, on_delete: :delete
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

    attribute :attributes, :map do
      allow_nil? false
      default %{}
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organisation, ThreatShield.Accounts.Organisation do
      allow_nil? false
      attribute_type :integer
    end

    has_many :threats, ThreatShield.ThreatManagement.Threat
    has_many :assets, ThreatShield.ThreatManagement.Asset
  end

  validations do
    validate {ThreatShield.Validations.AttributeValues, attribute: :attributes}
  end

  identities do
    # The first key holds the error. The index has the columns in the other order.
    identity :unique_name_per_organisation, [:name, :organisation_id],
      field_names: [:name],
      message: "is already used by another system of this organisation"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :attributes]

      argument :organisation_id, :integer, allow_nil?: false
      change manage_relationship(:organisation_id, :organisation, type: :append_and_remove)
    end

    update :update do
      accept [:name, :description, :attributes]
      require_atomic? false
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

  def attributes_config do
    @attributes
  end

  def describe(%{name: name, description: description, attributes: attributes}) do
    name_string = """
    The name of the system is "#{name}". It can be described as follows: "#{description}".
    """

    attribute_values =
      "The system has the following properties:\n" <>
        ((attributes || %{})
         |> Enum.filter(fn {_, val} -> val != "" end)
         |> Enum.map_join("\n", fn {key, val} -> ~s{"#{key}: ", "#{val}"} end))

    attribute_description =
      "The system properties have the following user-facing descriptions:\n" <>
        (@attributes
         |> Enum.map_join("\n", fn d -> ~s{"#{d.name}: ", "#{d.description}"} end))

    [name_string, attribute_values, attribute_description]
    |> Enum.join(" ")
  end
end
