defmodule AshThreatShield.ThreatManagement do
  @moduledoc """
  The threat model of an organisation: systems, assets, threats, risks and
  mitigations. The functions defined here are the public API: call them with the
  acting user as `actor:`, the policies of the resources decide what the actor may
  do (see `AshThreatShield.Authorization`).

  The `tools` below are the MCP tools of ash_ai. A host serves them with
  `AshAi.Mcp.Router` and its `otp_app` (when this domain is in its `:ash_domains`),
  and can choose or exclude tools with the options `tools` and `exclude_actions`.
  """
  use Ash.Domain,
    otp_app: :ash_threat_shield,
    extensions: [AshAi],
    # The host lists the domain in the :ash_domains of its own application.
    validate_config_inclusion?: false

  alias AshThreatShield.ThreatManagement.{Asset, Mitigation, Risk, System, Threat, ThreatModel}

  # The tools of chat agents over MCP. They run with the actor of the MCP request,
  # so the policies apply. Deleting is left to the application.
  tools do
    tool(:threat_model_context, ThreatModel, :context)
    tool(:risk_summary, ThreatModel, :risk_summary)

    tool(:list_systems, System, :for_organisation)
    tool(:create_system, System, :create)
    tool(:update_system, System, :update)

    tool :list_assets, Asset, :for_organisation do
      description "Lists the assets of an organisation. Filter by system_id for the " <>
                    "assets of one system."
    end

    tool(:create_asset, Asset, :create)
    tool(:update_asset, Asset, :update)

    tool :list_threats, Threat, :for_organisation do
      description "Lists the threats of an organisation with the names of their system " <>
                    "and asset. Filter by system_id or asset_id for the threats of one " <>
                    "system or asset."

      load [:system_name, :asset_name]
    end

    tool(:create_threat, Threat, :create)
    tool(:update_threat, Threat, :update)

    tool :list_risks, Risk, :for_organisation do
      description "Lists the risks of an organisation with the name of their threat and " <>
                    "the estimated risk cost per year. Filter by threat_id for the risks " <>
                    "of one threat."

      load [:threat_name, :estimated_risk_cost]
    end

    tool(:create_risk, Risk, :create)
    tool(:update_risk, Risk, :update)

    tool :list_mitigations, Mitigation, :for_organisation do
      description "Lists the mitigations of an organisation. Filter by risk_id for the " <>
                    "mitigations of one risk."
    end

    tool(:create_mitigation, Mitigation, :create)
    tool(:update_mitigation, Mitigation, :update)
  end

  resources do
    resource AshThreatShield.ThreatManagement.System do
      define :list_systems, action: :for_organisation, args: [:organisation_id]
      define :get_system, action: :read, get_by: [:id]
      define :create_system, action: :create
      define :update_system, action: :update
      define :destroy_system, action: :destroy, get_by: [:id]
    end

    resource AshThreatShield.ThreatManagement.Asset do
      define :list_assets, action: :for_organisation, args: [:organisation_id]
      define :list_assets_of_system, action: :for_system, args: [:system_id]
      define :get_asset, action: :read, get_by: [:id]
      define :create_asset, action: :create
      define :update_asset, action: :update
      define :destroy_asset, action: :destroy, get_by: [:id]
    end

    resource AshThreatShield.ThreatManagement.Threat do
      define :list_threats, action: :for_organisation, args: [:organisation_id]
      define :list_threats_of_system, action: :for_system, args: [:system_id]
      define :list_threats_of_asset, action: :for_asset, args: [:asset_id]
      define :get_threat, action: :read, get_by: [:id]
      define :create_threat, action: :create
      define :update_threat, action: :update
      define :destroy_threat, action: :destroy, get_by: [:id]
    end

    resource AshThreatShield.ThreatManagement.Risk do
      define :list_risks, action: :for_organisation, args: [:organisation_id]
      define :get_risk, action: :read, get_by: [:id]
      define :create_risk, action: :create
      define :update_risk, action: :update
      define :destroy_risk, action: :destroy, get_by: [:id]
    end

    resource AshThreatShield.ThreatManagement.Mitigation do
      define :list_mitigations, action: :for_organisation, args: [:organisation_id]
      define :get_mitigation, action: :read, get_by: [:id]
      define :create_mitigation, action: :create
      define :update_mitigation, action: :update
      define :destroy_mitigation, action: :destroy, get_by: [:id]
    end

    resource AshThreatShield.ThreatManagement.ThreatModel do
      define :threat_model_context, action: :context, args: [:organisation_id]
      define :risk_summary, action: :risk_summary, args: [:organisation_id]
      define :suggest_assets, action: :suggest_assets, args: [:organisation_id]
      define :suggest_threats, action: :suggest_threats, args: [:organisation_id]
      define :suggest_risks, action: :suggest_risks, args: [:threat_id]
      define :suggest_mitigations, action: :suggest_mitigations, args: [:risk_id]
    end
  end
end
