defmodule ThreatShieldWeb.Labels do
  use Phoenix.Component

  use ThreatShieldWeb, :verified_routes
  import ThreatShieldWeb.Gettext

  alias AshThreatShield.ThreatManagement.System
  alias AshThreatShield.ThreatManagement.Asset
  alias AshThreatShield.ThreatManagement.Threat
  alias AshThreatShield.ThreatManagement.Risk
  alias AshThreatShield.ThreatManagement.{MitigationStatus, RiskStatus}

  def system_label(%Risk{} = risk) do
    system_label(risk.threat)
  end

  def system_label(%Threat{} = threat) do
    system_label(threat.system)
  end

  def system_label(%Asset{} = asset) do
    system_label(asset.system)
  end

  def system_label(%System{} = system), do: system.name

  def system_label(_), do: "-"

  def asset_label(%Risk{} = risk) do
    asset_label(risk.threat)
  end

  def asset_label(%Threat{} = threat) do
    asset_label(threat.asset)
  end

  def asset_label(%Asset{} = asset) do
    asset.name
  end

  def asset_label(_), do: "-"

  def risk_status_label(status) when is_binary(status),
    do: risk_status_label(String.to_existing_atom(status))

  def risk_status_label(:identified), do: dgettext("risks", "State:identified")
  def risk_status_label(:assessed), do: dgettext("risks", "State:assessed")
  def risk_status_label(:mitigated), do: dgettext("risks", "State:mitigated")
  def risk_status_label(:accepted), do: dgettext("risks", "State:accepted")
  def risk_status_label(status), do: status

  def mitigation_status_label(status) when is_binary(status),
    do: mitigation_status_label(String.to_existing_atom(status))

  def mitigation_status_label(:open), do: dgettext("mitigations", "State:open")
  def mitigation_status_label(:in_progress), do: dgettext("mitigations", "State:in_progress")
  def mitigation_status_label(:implemented), do: dgettext("mitigations", "State:implemented")
  def mitigation_status_label(:verified), do: dgettext("mitigations", "State:verified")
  def mitigation_status_label(:failed), do: dgettext("mitigations", "State:failed")
  def mitigation_status_label(:deferred), do: dgettext("mitigations", "State:deferred")
  def mitigation_status_label(:obsolete), do: dgettext("mitigations", "State:obsolete")
  def mitigation_status_label(status), do: status

  def role_label(role) when is_binary(role),
    do: role_label(String.to_existing_atom(role))

  def role_label(:owner), do: dgettext("members", "Role:owner")
  def role_label(:editor), do: dgettext("members", "Role:editor")
  def role_label(:viewer), do: dgettext("members", "Role:viewer")

  @doc """
  The states of a risk with their labels, in the order of `RiskStatus`.
  """
  def available_risk_states() do
    Enum.map(RiskStatus.values(), &{&1, risk_status_label(&1)})
  end

  @doc """
  The states of a mitigation with their labels, in the order of `MitigationStatus`.
  """
  def available_mitigation_states() do
    Enum.map(MitigationStatus.values(), &{&1, mitigation_status_label(&1)})
  end
end
