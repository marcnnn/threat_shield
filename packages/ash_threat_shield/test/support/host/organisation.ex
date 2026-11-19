defmodule AshThreatShield.Test.Organisation do
  @moduledoc """
  The owner resource of the test host. Members read it; its creator becomes its
  owner.
  """
  use Ash.Resource,
    otp_app: :ash_threat_shield,
    domain: AshThreatShield.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @behaviour AshThreatShield.Owner

  alias AshThreatShield.Checks.OrganisationRole
  alias AshThreatShield.DynamicAttribute

  postgres do
    table "organisations"
    repo AshThreatShield.TestRepo
  end

  attributes do
    integer_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :attributes, :map, allow_nil?: false, default: %{}, public?: true
  end

  relationships do
    has_many :memberships, AshThreatShield.Test.Membership
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :attributes]

      change after_action(fn _changeset, organisation, context ->
               AshThreatShield.Test.Accounts.create_membership!(
                 %{role: :owner, user_id: context.actor.id, organisation_id: organisation.id},
                 authorize?: false
               )

               {:ok, organisation}
             end)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if {OrganisationRole, right: :view_organisation, path: []}
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end
  end

  @impl AshThreatShield.Owner
  def attributes_config do
    [%DynamicAttribute{name: "Industry", description: "Examples are finance and health."}]
  end
end
