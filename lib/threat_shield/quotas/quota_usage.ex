defmodule ThreatShield.Quotas.QuotaUsage do
  @moduledoc """
  Quota usage resource. Tracks how much of a quota has been used by an organisation or user.
  """
  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.Quotas,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "quota_usages"
    repo ThreatShield.Repo

    references do
      reference :organisation, on_delete: :delete
      # the usage stays counted for the organisation when the user is deleted
      reference :user, on_delete: :nilify
    end
  end

  attributes do
    integer_primary_key :id

    attribute :quota_type, :string do
      allow_nil? false
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
      default &DateTime.utc_now/0
      public? true
    end
  end

  relationships do
    belongs_to :organisation, ThreatShield.Accounts.Organisation do
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :user, ThreatShield.Accounts.User do
      allow_nil? true
      attribute_type :integer
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:quota_type, :amount, :message, :timestamp]

      argument :organisation_id, :integer, allow_nil?: false
      argument :user_id, :integer, allow_nil?: true

      change set_attribute(:organisation_id, arg(:organisation_id))
      change set_attribute(:user_id, arg(:user_id))
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
end
