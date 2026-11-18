defmodule ThreatShield.Quotas do
  use Ash.Domain,
    otp_app: :threat_shield

  resources do
    resource ThreatShield.Quotas.QuotaUsage
  end
end
