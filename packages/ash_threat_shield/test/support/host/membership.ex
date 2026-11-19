defmodule AshThreatShield.Test.Membership do
  @moduledoc """
  The role of a user in an organisation of the test host. The test authorization
  (`AshThreatShield.Test.Authorization`) reads it.
  """
  use Ash.Resource,
    otp_app: :ash_threat_shield,
    domain: AshThreatShield.Test.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "memberships"
    repo AshThreatShield.TestRepo

    references do
      reference :user, on_delete: :delete
      reference :organisation, on_delete: :delete
    end
  end

  attributes do
    integer_primary_key :id

    attribute :role, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:owner, :editor, :viewer]
    end
  end

  relationships do
    belongs_to :user, AshThreatShield.Test.User do
      allow_nil? false
      attribute_type :integer
      public? true
    end

    belongs_to :organisation, AshThreatShield.Test.Organisation do
      allow_nil? false
      attribute_type :integer
      public? true
    end
  end

  actions do
    defaults [:read, create: [:role, :user_id, :organisation_id]]
  end
end
