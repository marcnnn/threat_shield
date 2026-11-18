defmodule ThreatShield.ThreatManagement.ThreatModel.Actions.RiskSummary do
  @moduledoc """
  The figures of the risk board of an organisation, read with the actor.
  """

  use Ash.Resource.Actions.Implementation

  alias ThreatShield.Analytics.RiskAnalytics
  alias ThreatShield.{Accounts, ThreatManagement}
  alias ThreatShield.ThreatManagement.{MitigationStatus, RiskStatus}

  @impl true
  def run(input, _opts, context) do
    opts = Ash.Context.to_opts(context)
    org_id = input.arguments.organisation_id

    with {:ok, organisation} <-
           Accounts.get_organisation(
             org_id,
             Keyword.put(opts, :load, [:threat_count, :risk_count, :mitigation_count])
           ),
         {:ok, risks} <-
           ThreatManagement.list_risks(org_id, Keyword.put(opts, :load, [:estimated_risk_cost])),
         {:ok, mitigations} <- ThreatManagement.list_mitigations(org_id, opts) do
      {:ok,
       %{
         organisation_id: organisation.id,
         organisation_name: organisation.name,
         threat_count: organisation.threat_count,
         risk_count: organisation.risk_count,
         mitigation_count: organisation.mitigation_count,
         total_risk_cost: RiskAnalytics.sum_up_risk_costs(risks),
         unmitigated_risk_cost: RiskAnalytics.sum_up_risk_costs(risks, RiskStatus.unmitigated()),
         mitigated_risk_cost: RiskAnalytics.sum_up_risk_costs(risks, :mitigated),
         risks_by_status: count_by_status(risks, RiskStatus.values()),
         mitigations_by_status: count_by_status(mitigations, MitigationStatus.values()),
         top_risks_by_severity: risks |> RiskAnalytics.top_10_severity() |> Enum.map(&risk/1),
         top_risks_by_cost: risks |> RiskAnalytics.top_10_risk_costs() |> Enum.map(&risk/1)
       }}
    end
  end

  defp count_by_status(records, states) do
    counts = Enum.frequencies_by(records, & &1.status)
    Map.new(states, &{&1, Map.get(counts, &1, 0)})
  end

  defp risk(risk) do
    %{
      id: risk.id,
      name: risk.name,
      threat_id: risk.threat_id,
      status: risk.status,
      severity: risk.severity,
      probability: risk.probability,
      estimated_cost: risk.estimated_cost,
      estimated_risk_cost: risk.estimated_risk_cost
    }
  end
end
