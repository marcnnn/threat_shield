defmodule ThreatShield.Accounts.Token do
  @moduledoc """
  The tokens of AshAuthentication: sessions, API sign ins, confirmations, password
  resets and revocations. Only AshAuthentication works with them.
  """

  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "user_tokens"
    repo ThreatShield.Repo

    # match the columns of the migrations
    migration_types jti: {:varchar, 255},
                    subject: {:varchar, 255},
                    purpose: {:varchar, 255},
                    created_at: :naive_datetime_usec,
                    updated_at: :naive_datetime_usec

    migration_defaults created_at: ~S|fragment("now()")|,
                       updated_at: ~S|fragment("now()")|

    custom_indexes do
      # The tokens are looked up by jti (sign in), by subject (sign out everywhere) and
      # by expiry (clean up). The unique index on jti duplicates the primary key.
      index [:jti], unique: true, name: "user_tokens_jti_index"
      index [:subject]
      index [:expires_at]
    end
  end

  actions do
    defaults [:read, :destroy]
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end
end
