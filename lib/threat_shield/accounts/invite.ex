defmodule ThreatShield.Accounts.Invite do
  @moduledoc """
  An invite of an email address to an organisation. The invitee accepts it by
  address (`Membership` action `:accept_invite`) or with the link that contains the
  token (`:join_with_token`). Invites expire.
  """
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import ThreatShield.Const.RetentionTimes, only: [invite_lifetime_in_seconds: 0]

  alias AshThreatShield.Checks.{OrganisationRole, OrganisationRoleForCreate}
  alias ThreatShield.Checks.InviteAddressee

  postgres do
    table "invites"
    repo ThreatShield.Repo

    identity_index_names unique_token: "invites_token_index"

    # match the columns of the Ecto migrations
    migration_types token: {:varchar, 255},
                    inserted_at: :naive_datetime,
                    updated_at: :naive_datetime

    migration_defaults inserted_at: "nil", updated_at: "nil"

    references do
      reference :organisation, on_delete: :delete, index?: true
    end
  end

  attributes do
    integer_primary_key :id

    attribute :token, :string do
      allow_nil? false
      sensitive? true
    end

    # citext in the database, so that addresses compare case-insensitively
    attribute :email, :ci_string do
      allow_nil? false
      public? true
      constraints max_length: 160
      description "The email address of the invitee."
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organisation, ThreatShield.Accounts.Organisation do
      allow_nil? false
      attribute_type :integer
      public? true
    end
  end

  calculations do
    # The invitee is not a member yet and may not read the organisation itself.
    calculate :organisation_name, :string, expr(organisation.name) do
      allow_nil? false
      public? true
      description "The name of the organisation."
    end
  end

  validations do
    validate match(:email, ~r/^[^\s]+@[^\s]+$/),
      message: "must have the @ sign and no spaces"
  end

  identities do
    # Named after the index of the migration, so that the error of the unique
    # constraint goes to the field :email.
    identity :organisation_id_email, [:organisation_id, :email],
      field_names: [:email],
      message: "has already been invited to this organisation"

    identity :unique_token, [:token]
  end

  actions do
    read :read do
      primary? true

      description "Lists the invites of the organisations where the actor may invite members, " <>
                    "and the invites to the actor."
    end

    read :received do
      description "Lists the open invites to the confirmed email address of the actor."

      filter expr(
               email == ^actor(:email) and
                 inserted_at >= ago(^invite_lifetime_in_seconds(), :second)
             )
    end

    read :by_token do
      description "Gets an open invite by the token of its link."
      get? true

      argument :token, :string do
        allow_nil? false
        sensitive? true
      end

      filter expr(
               token == ^arg(:token) and
                 inserted_at >= ago(^invite_lifetime_in_seconds(), :second)
             )
    end

    read :open do
      description "Lists the invites that have not expired."
      filter expr(inserted_at >= ago(^invite_lifetime_in_seconds(), :second))
    end

    read :expired do
      description "Lists the invites that have expired."
      filter expr(inserted_at < ago(^invite_lifetime_in_seconds(), :second))
    end

    create :create do
      description "Invites an email address to an organisation and sends the link to " <>
                    "join to the address. An address can be invited once per organisation."

      accept [:email, :organisation_id]
      validate ThreatShield.Accounts.Validations.NotAMember
      change ThreatShield.Accounts.Changes.GenerateInviteToken
      change ThreatShield.Accounts.Changes.SendInviteEmail
    end

    destroy :destroy do
      primary? true
      description "Revokes an invite of an organisation."
    end

    destroy :reject do
      description "Rejects an invite to the actor."
    end
  end

  policies do
    # The token is the secret of the invite link: whoever has it may read the invite,
    # also before signing up.
    bypass action(:by_token) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if {OrganisationRole, right: :invite_new_members}
      authorize_if InviteAddressee
    end

    policy action_type(:create) do
      authorize_if {OrganisationRoleForCreate, right: :invite_new_members}
    end

    policy action(:destroy) do
      authorize_if {OrganisationRole, right: :invite_new_members}
    end

    policy action(:reject) do
      authorize_if InviteAddressee
    end
  end

  def expiration_point(%{inserted_at: inserted_at}) do
    NaiveDateTime.add(inserted_at, invite_lifetime_in_seconds())
  end
end
