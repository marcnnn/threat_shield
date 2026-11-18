defmodule ThreatShield.Accounts.Membership do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "memberships"
    repo ThreatShield.Repo

    references do
      reference :user, on_delete: :delete
      reference :organisation, on_delete: :delete
    end
  end

  attributes do
    integer_primary_key :id

    attribute :role, :atom do
      constraints one_of: [:owner, :editor, :viewer]
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :user, ThreatShield.Accounts.User do
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :organisation, ThreatShield.Accounts.Organisation do
      allow_nil? false
      attribute_type :integer
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:role]

      argument :user_id, :integer, allow_nil?: false
      argument :organisation_id, :integer, allow_nil?: false

      change manage_relationship(:user_id, :user, type: :append_and_remove)
      change manage_relationship(:organisation_id, :organisation, type: :append_and_remove)
    end

    update :update_role do
      accept [:role]
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
      authorize_if relates_to_actor_via(:user)
      authorize_if expr(exists(organisation.memberships, user_id == ^actor(:id)))
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(
                     exists(organisation.memberships, user_id == ^actor(:id) and role == :owner)
                   )
    end
  end
end
