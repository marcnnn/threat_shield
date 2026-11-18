defmodule ThreatShield.Accounts.Invite do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import ThreatShield.Const.RetentionTimes, only: [invite_lifetime_in_seconds: 0]

  require Ash.Query

  postgres do
    table "invites"
    repo ThreatShield.Repo

    identity_index_names unique_email_per_organisation: "invites_organisation_id_email_index"

    references do
      reference :organisation, on_delete: :delete
    end
  end

  attributes do
    integer_primary_key :id

    attribute :token, :string do
      allow_nil? false
      public? true
    end

    # citext in the database, so that addresses compare case-insensitively
    attribute :email, :ci_string do
      allow_nil? false
      public? true
      constraints max_length: 160
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organisation, ThreatShield.Accounts.Organisation do
      allow_nil? false
      attribute_type :integer
    end
  end

  validations do
    validate match(:email, ~r/^[^\s]+@[^\s]+$/),
      message: "must have the @ sign and no spaces"
  end

  identities do
    # The first key holds the error. The index has the columns in the other order.
    identity :unique_email_per_organisation, [:email, :organisation_id],
      field_names: [:email],
      message: "has already been invited to this organisation"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:email]

      argument :organisation_id, :integer, allow_nil?: false

      change manage_relationship(:organisation_id, :organisation, type: :append_and_remove)

      change fn changeset, _context ->
        token = :crypto.strong_rand_bytes(128) |> Base.url_encode64(padding: false)
        Ash.Changeset.change_attribute(changeset, :token, token)
      end
    end

    read :get_by_token do
      argument :token, :string, allow_nil?: false
      get? true

      prepare fn query, _context ->
        cutoff = ThreatShield.Accounts.Invite.cutoff_time()
        value = Ash.Query.get_argument(query, :token)

        query
        |> Ash.Query.filter(expr(token == ^value and inserted_at >= ^cutoff))
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

    read :for_user_email do
      argument :email, :ci_string, allow_nil?: false

      prepare fn query, _context ->
        cutoff = ThreatShield.Accounts.Invite.cutoff_time()
        address = Ash.Query.get_argument(query, :email)

        query
        |> Ash.Query.filter(expr(email == ^address and inserted_at >= ^cutoff))
      end
    end

    read :expired do
      prepare fn query, _context ->
        cutoff = ThreatShield.Accounts.Invite.cutoff_time()

        query
        |> Ash.Query.filter(expr(inserted_at < ^cutoff))
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if expr(
                     exists(organisation.memberships, user_id == ^actor(:id) and role == :owner)
                   )
    end

    policy action_type([:update, :destroy]) do
      authorize_if always()
    end
  end

  def cutoff_time do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(-invite_lifetime_in_seconds())
  end

  def generate_url(%{token: token}) do
    ThreatShieldWeb.Endpoint.url() <> "/join/" <> token
  end

  def expiration_point(%{inserted_at: inserted_at}) do
    NaiveDateTime.add(inserted_at, invite_lifetime_in_seconds())
  end
end
