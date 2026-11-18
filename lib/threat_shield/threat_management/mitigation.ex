defmodule ThreatShield.ThreatManagement.Mitigation do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.ThreatManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "mitigations"
    repo ThreatShield.Repo

    references do
      reference :risk, on_delete: :delete
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

    attribute :issue_link, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
    end

    attribute :status, :atom do
      constraints one_of: [
                    :open,
                    :in_progress,
                    :implemented,
                    :verified,
                    :failed,
                    :deferred,
                    :obsolete
                  ]

      default :open
      public? true
    end

    attribute :implementation_date, :date do
      allow_nil? true
      public? true
    end

    attribute :implementation_notes, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
    end

    attribute :is_implemented, :boolean do
      default false
      public? true
    end

    attribute :verification_date, :date do
      allow_nil? true
      public? true
    end

    attribute :verification_method, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
    end

    attribute :verification_result, :string do
      allow_nil? true
      public? true
      constraints max_length: 255
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :risk, ThreatShield.ThreatManagement.Risk do
      allow_nil? false
      attribute_type :integer
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
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

      argument :risk_id, :integer, allow_nil?: false
      change manage_relationship(:risk_id, :risk, type: :append_and_remove)

      change fn changeset, _context ->
        update_implementation_status(changeset)
      end
    end

    update :update do
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

      require_atomic? false

      change fn changeset, _context ->
        update_implementation_status(changeset)
      end
    end

    read :for_user do
      argument :user_id, :integer, allow_nil?: false
      argument :roles, {:array, :atom}, allow_nil?: false

      filter expr(
               exists(
                 risk.threat.organisation.memberships,
                 user_id == ^arg(:user_id) and role in ^arg(:roles)
               )
             )
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(exists(risk.threat.organisation.memberships, user_id == ^actor(:id)))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(
                     exists(
                       risk.threat.organisation.memberships,
                       user_id == ^actor(:id) and role in [:owner, :editor]
                     )
                   )
    end
  end

  defp update_implementation_status(changeset) do
    status = Ash.Changeset.get_attribute(changeset, :status)

    implemented = status in [:implemented, :verified]

    Ash.Changeset.change_attribute(changeset, :is_implemented, implemented)
  end
end
