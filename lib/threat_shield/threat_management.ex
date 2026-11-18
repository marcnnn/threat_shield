defmodule ThreatShield.ThreatManagement do
  @moduledoc """
  The threat model of an organisation: systems, assets, threats, risks and
  mitigations. The functions defined here are the public API: call them with the
  acting user as `actor:`, the policies of the resources decide what the actor may
  do (see `ThreatShield.Accounts.Rights`).
  """
  use Ash.Domain,
    otp_app: :threat_shield

  resources do
    resource ThreatShield.ThreatManagement.System do
      define :list_systems, action: :for_organisation, args: [:organisation_id]
      define :get_system, action: :read, get_by: [:id]
      define :create_system, action: :create
      define :update_system, action: :update
      define :destroy_system, action: :destroy, get_by: [:id]
    end

    resource ThreatShield.ThreatManagement.Asset do
      define :list_assets, action: :for_organisation, args: [:organisation_id]
      define :list_assets_of_system, action: :for_system, args: [:system_id]
      define :get_asset, action: :read, get_by: [:id]
      define :create_asset, action: :create
      define :update_asset, action: :update
      define :destroy_asset, action: :destroy, get_by: [:id]
    end

    resource ThreatShield.ThreatManagement.Threat do
      define :list_threats, action: :for_organisation, args: [:organisation_id]
      define :list_threats_of_system, action: :for_system, args: [:system_id]
      define :list_threats_of_asset, action: :for_asset, args: [:asset_id]
      define :get_threat, action: :read, get_by: [:id]
      define :create_threat, action: :create
      define :update_threat, action: :update
      define :destroy_threat, action: :destroy, get_by: [:id]
    end

    resource ThreatShield.ThreatManagement.Risk do
      define :list_risks, action: :for_organisation, args: [:organisation_id]
      define :get_risk, action: :read, get_by: [:id]
      define :create_risk, action: :create
      define :update_risk, action: :update
      define :destroy_risk, action: :destroy, get_by: [:id]
    end

    resource ThreatShield.ThreatManagement.Mitigation do
      define :list_mitigations, action: :for_organisation, args: [:organisation_id]
      define :get_mitigation, action: :read, get_by: [:id]
      define :create_mitigation, action: :create
      define :update_mitigation, action: :update
      define :destroy_mitigation, action: :destroy, get_by: [:id]
    end

    resource ThreatShield.ThreatManagement.ThreatModel do
      define :threat_model_context, action: :context, args: [:organisation_id]
      define :risk_summary, action: :risk_summary, args: [:organisation_id]
    end
  end
end
