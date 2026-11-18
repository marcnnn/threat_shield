defmodule ThreatShield.ThreatManagement.ThreatModel do
  @moduledoc """
  Views of the threat model of an organisation that are computed from its records:
  the description that the AI assistant uses as context, the risk summary of the
  risk board, and the suggestions of the AI assistant. The resource has no data of
  its own; its generic actions read the records with the actor, so the read policies
  of the records apply.

  The suggestions are new entities that the AI assistant proposes. They are not
  saved; the caller stores the ones that the user selects with the create actions.
  A suggestion needs the right to create such entities, and uses one AI request of
  the quota of the organisation.
  """

  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.ThreatManagement,
    authorizers: [Ash.Policy.Authorizer]

  alias ThreatShield.Checks.OrganisationRoleForCreate
  alias ThreatShield.ThreatManagement.{Asset, Mitigation, Risk, Threat}
  alias ThreatShield.ThreatManagement.ThreatModel.Actions

  actions do
    action :context, :string do
      description """
      Describes the threat model of an organisation in plain text: the organisation with \
      its properties and systems, the system, asset, threat or risk in focus, and the \
      entities that are known for the most specific one (with their ids). This is the \
      context that the built-in AI assistant of ThreatShield uses for its suggestions. \
      Read it before suggesting or creating systems, assets, threats, risks or \
      mitigations.\
      """

      argument :organisation_id, :integer do
        allow_nil? false
        description "The id of the organisation."
      end

      argument :system_id, :integer do
        description "The id of a system of the organisation to focus on."
      end

      argument :asset_id, :integer do
        description "The id of an asset of the organisation to focus on."
      end

      argument :threat_id, :integer do
        description "The id of a threat of the organisation to focus on."
      end

      argument :risk_id, :integer do
        description "The id of a risk of the organisation to focus on."
      end

      run Actions.Context
    end

    action :risk_summary, :map do
      description """
      Summarizes the risks of an organisation like the risk board: the numbers of \
      threats, risks and mitigations, the estimated risk costs in total, mitigated and \
      unmitigated, the risks and mitigations per status, and the ten risks with the \
      highest severity and the highest estimated cost.\
      """

      argument :organisation_id, :integer do
        allow_nil? false
        description "The id of the organisation."
      end

      run Actions.RiskSummary
    end

    action :suggest_assets, {:array, :struct} do
      description "Suggests new assets of an organisation or of one of its systems."
      constraints items: [instance_of: Asset]

      argument :organisation_id, :integer do
        allow_nil? false
        description "The id of the organisation."
      end

      argument :system_id, :integer do
        description "The id of a system of the organisation to suggest assets for."
      end

      run {Actions.Suggest, kind: :assets}
    end

    action :suggest_threats, {:array, :struct} do
      description "Suggests new threats of an organisation, of a system and/or of an asset."
      constraints items: [instance_of: Threat]

      argument :organisation_id, :integer do
        allow_nil? false
        description "The id of the organisation."
      end

      argument :system_id, :integer do
        description "The id of a system of the organisation to suggest threats for."
      end

      argument :asset_id, :integer do
        description "The id of an asset of the organisation to suggest threats for."
      end

      run {Actions.Suggest, kind: :threats}
    end

    action :suggest_risks, {:array, :struct} do
      description "Suggests new risks of a threat."
      constraints items: [instance_of: Risk]

      argument :threat_id, :integer do
        allow_nil? false
        description "The id of the threat."
      end

      run {Actions.Suggest, kind: :risks}
    end

    action :suggest_mitigations, {:array, :struct} do
      description "Suggests new mitigations of a risk."
      constraints items: [instance_of: Mitigation]

      argument :risk_id, :integer do
        allow_nil? false
        description "The id of the risk."
      end

      run {Actions.Suggest, kind: :mitigations}
    end
  end

  policies do
    # The actions read the records with the actor, and the read policies of the
    # records decide what the actor sees.
    policy action_type(:action) do
      authorize_if actor_present()
    end

    # A suggestion costs quota, so it needs the right to create what is suggested
    policy action(:suggest_assets) do
      authorize_if {OrganisationRoleForCreate, right: :create_asset}
    end

    policy action(:suggest_threats) do
      authorize_if {OrganisationRoleForCreate, right: :create_threat}
    end

    policy action(:suggest_risks) do
      authorize_if {OrganisationRoleForCreate, right: :create_risk, parent: {:threat_id, Threat}}
    end

    policy action(:suggest_mitigations) do
      authorize_if {OrganisationRoleForCreate,
                    right: :create_mitigation, parent: {:risk_id, Risk}}
    end
  end
end
