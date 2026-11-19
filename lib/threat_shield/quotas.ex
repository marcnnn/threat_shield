defmodule ThreatShield.Quotas do
  @moduledoc """
  The quotas of organisations, such as the AI requests per month. The usage is
  recorded by `ThreatShield.Quotas.QuotaManager`, a system operation without an actor.
  """
  use Ash.Domain,
    otp_app: :threat_shield

  resources do
    resource ThreatShield.Quotas.QuotaUsage do
      define :create_quota_usage, action: :create
      define :consume_quota, action: :consume
      define :quota_usage, action: :get_usage, args: [:organisation_id, :quota_type, :since]
    end
  end
end
