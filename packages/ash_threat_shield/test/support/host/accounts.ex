defmodule AshThreatShield.Test.Accounts do
  @moduledoc """
  The accounts of the test host: users, the organisations that own the threat
  models (the configured owner resource), and memberships with roles.
  """
  use Ash.Domain, otp_app: :ash_threat_shield

  resources do
    resource AshThreatShield.Test.User do
      define :create_user, action: :create
    end

    resource AshThreatShield.Test.Organisation do
      define :create_organisation, action: :create
      define :get_organisation, action: :read, get_by: [:id]
    end

    resource AshThreatShield.Test.Membership do
      define :create_membership, action: :create
    end
  end
end
