defmodule ThreatShield.ThreatManagement.Asset do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.ThreatManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias ThreatShield.ThreatManagement.Validations.SameOrganisation

  postgres do
    table "assets"
    repo ThreatShield.Repo

    references do
      reference :organisation, on_delete: :delete
      # deleting a system deletes its assets
      reference :system, on_delete: :delete
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
      allow_nil? true
      public? true
      constraints max_length: 4000
    end

    attribute :criticality_loss, :float do
      allow_nil? true
      public? true
      constraints min: 0, max: 5
    end

    attribute :criticality_theft, :float do
      allow_nil? true
      public? true
      constraints min: 0, max: 5
    end

    attribute :criticality_publication, :float do
      allow_nil? true
      public? true
      constraints min: 0, max: 5
    end

    attribute :criticality_overall, :float do
      allow_nil? true
      public? true
      constraints min: 0, max: 5
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

    has_many :threats, ThreatShield.ThreatManagement.Threat
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :description,
        :system_id,
        :criticality_loss,
        :criticality_theft,
        :criticality_publication,
        :criticality_overall
      ]

      argument :organisation_id, :integer, allow_nil?: false
      change set_attribute(:organisation_id, arg(:organisation_id))

      # an asset may only belong to a system of its own organisation
      validate {SameOrganisation,
                attribute: :system_id, resource: ThreatShield.ThreatManagement.System},
               where: [changing(:system_id)]

      change fn changeset, _context ->
        update_overall_criticality(changeset)
      end
    end

    update :update do
      accept [
        :name,
        :description,
        :system_id,
        :criticality_loss,
        :criticality_theft,
        :criticality_publication,
        :criticality_overall
      ]

      require_atomic? false

      validate {SameOrganisation,
                attribute: :system_id, resource: ThreatShield.ThreatManagement.System},
               where: [changing(:system_id)]

      change fn changeset, _context ->
        update_overall_criticality(changeset)
      end
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

  def calc_overall_criticality(%{
        criticality_loss: loss,
        criticality_theft: theft,
        criticality_publication: publication,
        criticality_overall: overall
      }) do
    if not is_nil(loss) and not is_nil(theft) and not is_nil(publication) do
      calc = (loss + theft + publication) / 3
      max(calc, overall || 0.0)
    else
      overall
    end
  end

  defp update_overall_criticality(changeset) do
    loss = Ash.Changeset.get_attribute(changeset, :criticality_loss)
    theft = Ash.Changeset.get_attribute(changeset, :criticality_theft)
    publication = Ash.Changeset.get_attribute(changeset, :criticality_publication)
    overall = Ash.Changeset.get_attribute(changeset, :criticality_overall)

    if not is_nil(loss) and not is_nil(theft) and not is_nil(publication) do
      calc = (loss + theft + publication) / 3
      new_overall = max(calc, overall || 0.0)
      Ash.Changeset.change_attribute(changeset, :criticality_overall, new_overall)
    else
      changeset
    end
  end
end
