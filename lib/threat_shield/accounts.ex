defmodule ThreatShield.Accounts do
  use Ash.Domain,
    otp_app: :threat_shield

  resources do
    resource ThreatShield.Accounts.User
    resource ThreatShield.Accounts.Organisation
    resource ThreatShield.Accounts.Membership
    resource ThreatShield.Accounts.Invite
    resource ThreatShield.Accounts.Token
  end
end
