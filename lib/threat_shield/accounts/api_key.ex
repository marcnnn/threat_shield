defmodule ThreatShield.Accounts.ApiKey do
  @moduledoc """
  A personal API key, for clients such as chat agents that act for a user. Only a
  hash is stored. The key itself is in `api_key.__metadata__.plaintext_api_key`
  right after creation and cannot be read later.
  """

  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "api_keys"
    repo ThreatShield.Repo

    references do
      reference :user, on_delete: :delete, index?: true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :api_key_hash, :binary do
      allow_nil? false
      sensitive? true
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :user, ThreatShield.Accounts.User do
      allow_nil? false
      attribute_type :integer
    end
  end

  calculations do
    calculate :valid, :boolean, expr(expires_at > now())
  end

  identities do
    identity :unique_api_key, [:api_key_hash]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Create an API key for the actor."
      primary? true
      accept [:expires_at]

      change relate_actor(:user)

      change {AshAuthentication.Strategy.ApiKey.GenerateApiKey,
              prefix: :threatshield, hash: :api_key_hash}
    end
  end

  policies do
    # The sign in with an API key reads the key
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:create) do
      # A key must not create further keys
      forbid_if AshAuthentication.Checks.UsingApiKey
      authorize_if actor_present()
    end

    policy action_type([:read, :destroy]) do
      authorize_if relates_to_actor_via(:user)
    end
  end
end
