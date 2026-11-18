defmodule ThreatShield.ThreatManagement do
  use Ash.Domain,
    otp_app: :threat_shield

  resources do
    resource ThreatShield.ThreatManagement.System
    resource ThreatShield.ThreatManagement.Asset
    resource ThreatShield.ThreatManagement.Threat
    resource ThreatShield.ThreatManagement.Risk
    resource ThreatShield.ThreatManagement.Mitigation
  end
end
