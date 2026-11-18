defmodule ThreatShield.Accounts.User do
  @moduledoc """
  A user account, authenticated with AshAuthentication.

  Sessions are tokens of `ThreatShield.Accounts.Token`. Every token is stored, and a
  token authenticates only while it is stored and not revoked, so that signing out
  ends a session for good.

  The emails of the account carry links into the web application. This resource does
  not know the routes: the caller passes the URL builders in the action context, see
  `ThreatShield.Accounts.Senders.Urls`.
  """

  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  alias AshAuthentication.Strategy.Password
  alias ThreatShield.Accounts.User
  alias ThreatShield.Accounts.Senders

  @password_constraints [min_length: 12, max_length: 72]

  postgres do
    table "users"
    repo ThreatShield.Repo

    identity_index_names unique_email: "users_email_index"
  end

  authentication do
    tokens do
      enabled? true
      token_resource ThreatShield.Accounts.Token
      store_all_tokens? true
      require_token_presence_for_authentication? true
      # Also the lifetime of the "remember me" cookie
      token_lifetime {60, :days}

      signing_secret fn _, _ ->
        Application.fetch_env(:threat_shield, :token_signing_secret)
      end
    end

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password

        # The registration form has no confirmation field. The actions that set a
        # new password for an existing user validate the confirmation themselves.
        confirmation_required? false
        sign_in_tokens_enabled? false

        resettable do
          sender Senders.SendPasswordResetEmail
          token_lifetime {1, :days}
        end
      end

      api_key :api_key do
        api_key_relationship :valid_api_keys
        api_key_hash_attribute :api_key_hash
      end
    end

    add_ons do
      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        confirm_action_name :confirm
        require_interaction? true
        sender Senders.SendConfirmationEmail
      end

      # A new address is written only when the link sent to it is followed. The
      # account stays confirmed in the meantime.
      confirmation :confirm_email_change do
        monitor_fields [:email]
        confirm_on_create? false
        confirm_on_update? true
        inhibit_updates? true
        confirmed_at_field :email_change_confirmed_at
        confirm_action_name :confirm_email_change
        require_interaction? true
        token_lifetime {7, :days}
        sender Senders.SendEmailChangeConfirmationEmail
      end

      log_out_everywhere do
        apply_on_password_change? true
      end
    end
  end

  attributes do
    integer_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
      constraints max_length: 160
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

    attribute :email_change_confirmed_at, :utc_datetime_usec do
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

    has_many :api_keys, ThreatShield.Accounts.ApiKey

    has_many :valid_api_keys, ThreatShield.Accounts.ApiKey do
      filter expr(valid)
    end
  end

  identities do
    identity :unique_email, [:email] do
      eager_check? true
    end
  end

  validations do
    validate match(:email, ~r/^[^\s]+@[^\s]+$/) do
      message "must have the @ sign and no spaces"
      where changing(:email)
    end
  end

  actions do
    defaults [:read]

    read :get_by_email do
      argument :email, :ci_string, allow_nil?: false
      get? true
      filter expr(email == ^arg(:email))
    end

    create :register_with_password do
      description "Register a new user with an email address and a password."
      accept [:email, :first_name, :last_name]

      argument :password, :string do
        allow_nil? false
        sensitive? true
        constraints @password_constraints
      end

      argument :accept_toc, :boolean do
        description "Whether the user accepts the terms of service and the privacy policy."
        allow_nil? false
        default false
      end

      validate argument_equals(:accept_toc, true), message: "must be accepted"

      change Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange

      metadata :token, :string, allow_nil?: false
    end

    read :sign_in_with_password do
      description "Sign in with an email address and a password."
      get? true

      argument :email, :ci_string, allow_nil?: false
      argument :password, :string, allow_nil?: false, sensitive?: true

      prepare Password.SignInPreparation

      metadata :token, :string, allow_nil?: false
    end

    read :sign_in_with_api_key do
      description "Sign in with a personal API key."
      get? true

      argument :api_key, :string, allow_nil?: false, sensitive?: true

      prepare AshAuthentication.Strategy.ApiKey.SignInPreparation
    end

    action :request_password_reset_with_password do
      description "Send password reset instructions to a user, if the address is known."
      argument :email, :ci_string, allow_nil?: false
      run {Password.RequestPasswordReset, action: :get_by_email}
    end

    read :get_by_reset_token do
      description "Get the user that a valid password reset token was issued for."
      get? true

      argument :reset_token, :string, allow_nil?: false, sensitive?: true

      prepare User.Preparations.FilterByResetToken
    end

    update :password_reset_with_password do
      description "Set a new password with a password reset token."
      accept []
      require_atomic? false

      argument :reset_token, :string, allow_nil?: false, sensitive?: true

      argument :password, :string do
        allow_nil? false
        sensitive? true
        constraints @password_constraints
      end

      argument :password_confirmation, :string, allow_nil?: true, sensitive?: true

      validate Password.ResetTokenValidation
      validate User.Validations.ResetTokenSubject
      validate User.Validations.PasswordConfirmation

      # The password change revokes all tokens of the user, the reset token too
      change Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange

      metadata :token, :string, allow_nil?: false
    end

    action :request_confirmation do
      description "Send new confirmation instructions to an unconfirmed user."
      argument :email, :ci_string, allow_nil?: false
      run User.Actions.RequestConfirmation
    end

    action :confirm_with_token, :struct do
      description "Confirm the user that the confirmation token was issued for."
      constraints instance_of: User
      argument :confirm, :string, allow_nil?: false, sensitive?: true
      run User.Actions.ConfirmWithToken
    end

    update :change_password do
      description "Change the password of the user. Signs the user out everywhere."
      accept []
      require_atomic? false

      argument :current_password, :string, allow_nil?: false, sensitive?: true

      argument :password, :string do
        allow_nil? false
        sensitive? true
        constraints @password_constraints
      end

      argument :password_confirmation, :string, allow_nil?: true, sensitive?: true

      validate User.Validations.PasswordConfirmation
      validate {User.Validations.CurrentPassword, argument: :current_password}

      change {Password.HashPasswordChange, strategy_name: :password}
    end

    update :change_email do
      description """
      Request a new email address. The address is changed only when the user follows
      the link that is sent to it.
      """

      accept [:email]
      require_atomic? false

      argument :current_password, :string, allow_nil?: false, sensitive?: true

      validate changing(:email), message: "did not change"
      validate {User.Validations.CurrentPassword, argument: :current_password}
    end

    update :confirm_email_change do
      description "Apply a requested email address with the token that was sent to it."
      accept [:email]
      require_atomic? false

      argument :confirm, :string, allow_nil?: false, sensitive?: true

      change AshAuthentication.AddOn.Confirmation.ConfirmChange
      change AshAuthentication.GenerateTokenChange
      # Following the link proves that the user owns the address
      change set_attribute(:confirmed_at, &DateTime.utc_now/0)

      metadata :token, :string, allow_nil?: false
    end
  end

  policies do
    # AshAuthentication runs its own actions (sign in by session token, storing
    # tokens, confirmations) with this context.
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # The entry points of the sign in flows. They need no actor, because each one
    # proves the identity itself: with the password, with a token that was sent by
    # email, or with an API key.
    bypass action([
             :register_with_password,
             :sign_in_with_password,
             :sign_in_with_api_key,
             :request_password_reset_with_password,
             :get_by_reset_token,
             :password_reset_with_password,
             :request_confirmation,
             :confirm_with_token
           ]) do
      authorize_if always()
    end

    # Users read themselves and the members of their organisations.
    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
      authorize_if expr(exists(memberships.organisation.memberships, user_id == ^actor(:id)))
    end

    # Users change only themselves. A confirmation of an email change also passes the
    # bypass above, because its token proves the request, and the token is valid only
    # for the user that it was issued for.
    policy action([:change_password, :change_email, :confirm_email_change]) do
      authorize_if expr(id == ^actor(:id))
    end
  end
end
