defmodule ThreatShield.Accounts.Membership do
  @moduledoc """
  The membership of a user in an organisation, with a role. Users join an
  organisation by accepting an invite; the creator of an organisation becomes its
  first owner.
  """
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias ThreatShield.Accounts.Changes.AcceptInvite
  alias ThreatShield.Accounts.Changes.KeepsOwner
  alias AshThreatShield.Checks.OrganisationRole

  postgres do
    table "memberships"
    repo ThreatShield.Repo

    identity_index_names unique_membership: "memberships_user_id_organisation_id_index"

    # match the column of the Ecto migration
    migration_types role: {:varchar, 255}

    references do
      reference :user, on_delete: :delete
      reference :organisation, on_delete: :delete, index?: true
    end
  end

  attributes do
    integer_primary_key :id

    attribute :role, ThreatShield.Accounts.Role do
      allow_nil? false
      default :viewer
      public? true
      description "The role of the member in the organisation: owner, editor or viewer."
    end
  end

  relationships do
    belongs_to :user, ThreatShield.Accounts.User do
      allow_nil? false
      attribute_type :integer
      public? true
    end

    belongs_to :organisation, ThreatShield.Accounts.Organisation do
      allow_nil? false
      attribute_type :integer
      public? true
    end
  end

  identities do
    identity :unique_membership, [:user_id, :organisation_id],
      message: "is already a member of this organisation"
  end

  actions do
    defaults [:read]

    create :create do
      description "Adds a user to an organisation. No actor is allowed to call it directly; " <>
                    "users join through invites."

      accept [:role, :user_id, :organisation_id]
    end

    create :accept_invite do
      description "Accepts an invite that was sent to the confirmed email address of the " <>
                    "actor. The actor becomes a viewer of the organisation."

      argument :invite_id, :integer do
        allow_nil? false
        description "The id of the invite."
      end

      change {AcceptInvite, by: :id}
    end

    create :join_with_token do
      description "Joins the organisation of an invite link. The actor becomes a viewer."

      argument :token, :string do
        allow_nil? false
        sensitive? true
        description "The token of the invite link."
      end

      change {AcceptInvite, by: :token}
    end

    update :update_role do
      description "Changes the role of a member. The last owner stays an owner."
      accept [:role]
      # the change locks the organisation and counts its owners
      require_atomic? false
      change KeepsOwner
    end

    destroy :destroy do
      primary? true
      description "Removes a member from an organisation. The last owner cannot be removed."
      # the change locks the organisation and counts its members
      require_atomic? false
      change {KeepsOwner, members: true}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if {OrganisationRole, right: :view_organisation}
    end

    policy action([:accept_invite, :join_with_token]) do
      authorize_if actor_present()
    end

    policy action(:update_role) do
      authorize_if {OrganisationRole, right: :edit_membership}
    end

    policy action_type(:destroy) do
      authorize_if {OrganisationRole, right: :delete_member}
    end
  end
end
