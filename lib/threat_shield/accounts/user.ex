defmodule ThreatShield.Accounts.User do
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "users"
    repo ThreatShield.Repo
  end

  authentication do
    tokens do
      enabled? true
      token_resource ThreatShield.Accounts.Token

      signing_secret fn _, _ ->
        Application.fetch_env(:threat_shield, :token_signing_secret)
      end
    end

    session_identifier :jti

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password

        register_action_accept [:first_name, :last_name]

        sign_in_tokens_enabled? true

        resettable do
          sender ThreatShield.Accounts.Senders.SendPasswordResetEmail
        end
      end
    end

    add_ons do
      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        confirm_action_name :confirm
        require_interaction? true
        sender ThreatShield.Accounts.Senders.SendConfirmationEmail
      end
    end
  end

  attributes do
    integer_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :first_name, :string do
      allow_nil? true
      public? true
      constraints max_length: 40
    end

    attribute :last_name, :string do
      allow_nil? true
      public? true
      constraints max_length: 40
    end

    attribute :global_roles, {:array, :string} do
      default []
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? true
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime_usec do
      allow_nil? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :organisations, ThreatShield.Accounts.Organisation do
      through ThreatShield.Accounts.Membership
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :organisation_id
    end

    has_many :memberships, ThreatShield.Accounts.Membership
  end

  identities do
    identity :unique_email, [:email]
  end

  actions do
    defaults [:read]

    read :get_by_email do
      argument :email, :ci_string, allow_nil?: false
      get? true
      filter expr(email == ^arg(:email))
    end

    read :get_by_id do
      argument :id, :integer, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end

    update :change_email do
      accept [:email]
      require_atomic? false
    end

    update :change_password do
      accept []
      require_atomic? false

      argument :current_password, :string, allow_nil?: false, sensitive?: true

      argument :password, :string,
        allow_nil?: false,
        sensitive?: true,
        constraints: [min_length: 12, max_length: 72]

      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true

      validate confirm(:password, :password_confirmation)

      change fn changeset, _context ->
        password = Ash.Changeset.get_argument(changeset, :password)

        if password do
          Ash.Changeset.change_attribute(
            changeset,
            :hashed_password,
            Bcrypt.hash_pwd_salt(password)
          )
        else
          changeset
        end
      end
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end
end
