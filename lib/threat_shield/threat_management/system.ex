defmodule ThreatShield.ThreatManagement.System do
  @moduledoc """
  A system of an organisation, e.g. an application or a piece of infrastructure.
  Deleting a system deletes its assets and threats.
  """
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.ThreatManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias ThreatShield.Checks.{OrganisationRole, OrganisationRoleForCreate}
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

  # replaceable for another application, see "Extraction" in AGENTS.md
  @repo Application.compile_env(:threat_shield, :threat_management_repo, ThreatShield.Repo)

  postgres do
    table "systems"
    repo @repo

    # match the columns of the Ecto migrations
    migration_types name: {:varchar, 255},
                    description: {:varchar, 4000},
                    inserted_at: :naive_datetime,
                    updated_at: :naive_datetime

    migration_defaults inserted_at: "nil", updated_at: "nil"

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
      description "The name of the system, unique in its organisation."
    end

    # a nullable column; the validation below requires a value
    attribute :description, :string do
      allow_nil? true
      public? true
      constraints max_length: 4000
      description "What the system does, its context and purpose."
    end

    attribute :attributes, :map do
      allow_nil? false
      default %{}
      public? true

      description "Properties of the system such as application type, audience, framework, " <>
                    "database and infrastructure, as a map of names to texts."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organisation, ThreatShield.Accounts.Organisation do
      allow_nil? false
      attribute_type :integer
      public? true
    end

    has_many :threats, ThreatShield.ThreatManagement.Threat, public?: true
    has_many :assets, ThreatShield.ThreatManagement.Asset, public?: true
  end

  validations do
    # only when the description is valid otherwise, e.g. not too long
    validate present(:description), message: "is required", only_when_valid?: true
    validate {ThreatShield.Validations.AttributeValues, attribute: :attributes}
  end

  identities do
    # Named after the index of the migration, so that the error of the unique
    # constraint goes to the field :name.
    identity :organisation_id_name, [:organisation_id, :name],
      field_names: [:name],
      message: "is already used by another system of this organisation"
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      description "Lists the systems of the organisations of the actor."
    end

    read :for_organisation do
      description "Lists the systems of an organisation."

      argument :organisation_id, :integer do
        allow_nil? false
        description "The id of the organisation."
      end

      filter expr(organisation_id == ^arg(:organisation_id))
    end

    create :create do
      description "Creates a system of an organisation."
      accept [:name, :description, :attributes, :organisation_id]
    end

    update :update do
      description "Changes the name, the description or the properties of a system."
      accept [:name, :description, :attributes]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if {OrganisationRole, right: :view_organisation}
    end

    policy action_type(:create) do
      authorize_if {OrganisationRoleForCreate, right: :create_system}
    end

    policy action_type(:update) do
      authorize_if {OrganisationRole, right: :edit_system}
    end

    policy action_type(:destroy) do
      authorize_if {OrganisationRole, right: :delete_system}
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
