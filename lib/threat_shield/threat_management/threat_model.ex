defmodule ThreatShield.ThreatManagement.ThreatModel do
  @moduledoc """
  Views of the threat model of an organisation that are computed from its records:
  the description that the AI assistant uses as context, and the risk summary of the
  risk board. The resource has no data of its own; its generic actions read the
  records with the actor, so the read policies of the records apply.
  """

  use Ash.Resource,
    otp_app: :threat_shield,
    domain: ThreatShield.ThreatManagement,
    authorizers: [Ash.Policy.Authorizer]

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
  end

  policies do
    # The actions read the records with the actor, and the read policies of the
    # records decide what the actor sees.
    policy action_type(:action) do
      authorize_if actor_present()
    end
  end
end
