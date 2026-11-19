defmodule AshThreatShield.Test.User do
  @moduledoc "A user of the test host, the actor of the tests."
  use Ash.Resource,
    otp_app: :ash_threat_shield,
    domain: AshThreatShield.Test.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "users"
    repo AshThreatShield.TestRepo
  end

  attributes do
    integer_primary_key :id
    attribute :email, :string, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, create: [:email]]
  end
end
