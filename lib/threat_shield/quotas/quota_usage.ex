defmodule ThreatShield.Quotas.QuotaUsage do
  @moduledoc """
  Quota usage resource. Tracks how much of a quota has been used by an organisation or user.
  """
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Quotas,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "quota_usages"
    repo ThreatShield.Repo

    # match the columns of the Ecto migrations
    migration_types quota_type: {:varchar, 255}, message: {:varchar, 255}
    migration_defaults amount: "0", timestamp: ~S|fragment("now()")|

    references do
      reference :organisation, on_delete: :delete, index?: true
      # the usage stays counted for the organisation when the user is deleted
      reference :user, on_delete: :nilify, index?: true
    end
  end

  attributes do
    integer_primary_key :id

    # nullable columns; the validations below require the values
    attribute :quota_type, :string do
      allow_nil? true
      public? true
    end

    attribute :amount, :float do
      default 0.0
      public? true
    end

    attribute :message, :string do
      allow_nil? true
      public? true
    end

    attribute :timestamp, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end
  end

  relationships do
    belongs_to :organisation, ThreatShield.Accounts.Organisation do
      allow_nil? true
      attribute_type :integer
      public? true
    end

    belongs_to :user, ThreatShield.Accounts.User do
      allow_nil? true
      attribute_type :integer
      public? true
    end
  end

  validations do
    validate present([:organisation_id, :quota_type]), on: [:create]
  end

  actions do
    defaults [:read]

    create :create do
      accept [:quota_type, :amount, :message, :timestamp, :organisation_id, :user_id]
    end

    action :consume do
      description "Records a usage of a quota of an organisation, if the quota allows it."
      transaction? true

      argument :organisation_id, :integer, allow_nil?: false
      argument :user_id, :integer
      argument :quota_type, :string, allow_nil?: false
      argument :amount, :float, allow_nil?: false, default: 1.0
      argument :message, :string

      run ThreatShield.Quotas.Actions.Consume
    end

    read :get_usage do
      argument :organisation_id, :integer, allow_nil?: false
      argument :quota_type, :string, allow_nil?: false
      argument :since, :utc_datetime_usec, allow_nil?: false

      filter expr(
               organisation_id == ^arg(:organisation_id) and
                 quota_type == ^arg(:quota_type) and
                 timestamp >= ^arg(:since)
             )
    end
  end

  # Quota bookkeeping is a system operation of `ThreatShield.Quotas.QuotaManager`,
  # which calls the actions without authorization. No actor may call them.
  policies do
    policy always() do
      forbid_if always()
    end
  end
end
