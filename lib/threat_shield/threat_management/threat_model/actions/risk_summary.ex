defmodule ThreatShield.ThreatManagement.ThreatModel.Actions.RiskSummary do
  @moduledoc """
  The figures of the risk board of an organisation, read with the actor. The
  database counts, sums, sorts and limits; no list of all risks is loaded.
  """

  use Ash.Resource.Actions.Implementation

  import Ash.Expr
  require Ash.Query

  alias ThreatShield.Accounts
  alias ThreatShield.ThreatManagement.{Mitigation, MitigationStatus, Risk, RiskStatus}

  @top 10

  @impl true
  def run(input, _opts, context) do
    opts = Ash.Context.to_opts(context)
    org_id = input.arguments.organisation_id

    with {:ok, organisation} <-
           Accounts.get_organisation(
             org_id,
             Keyword.put(opts, :load, [:threat_count, :risk_count, :mitigation_count])
           ),
         risks = Ash.Query.for_read(Risk, :for_organisation, %{organisation_id: org_id}, opts),
         mitigations =
           Ash.Query.for_read(Mitigation, :for_organisation, %{organisation_id: org_id}, opts),
         {:ok, risk_figures} <- Ash.aggregate(risks, risk_aggregates(), opts),
         {:ok, mitigation_figures} <-
           Ash.aggregate(mitigations, status_counts(MitigationStatus.values()), opts),
         {:ok, by_severity} <- top(risks, [severity: :desc_nils_last, id: :asc], opts),
         {:ok, by_cost} <-
           risks
           |> Ash.Query.filter(not is_nil(estimated_risk_cost))
           |> top([estimated_risk_cost: :desc, id: :asc], opts) do
      {:ok,
       %{
         organisation_id: organisation.id,
         organisation_name: organisation.name,
         threat_count: organisation.threat_count,
         risk_count: organisation.risk_count,
         mitigation_count: organisation.mitigation_count,
         total_risk_cost: risk_figures.total_risk_cost,
         unmitigated_risk_cost: risk_figures.unmitigated_risk_cost,
         mitigated_risk_cost: risk_figures.mitigated_risk_cost,
         risks_by_status: by_status(risk_figures, RiskStatus.values()),
         mitigations_by_status: by_status(mitigation_figures, MitigationStatus.values()),
         top_risks_by_severity: Enum.map(by_severity, &risk/1),
         top_risks_by_cost: Enum.map(by_cost, &risk/1)
       }}
    end
  end

  defp risk_aggregates do
    unmitigated = RiskStatus.unmitigated()

    [
      {:total_risk_cost, :sum, field: :estimated_risk_cost, default: 0},
      {:unmitigated_risk_cost, :sum,
       field: :estimated_risk_cost, default: 0, query: [filter: expr(status in ^unmitigated)]},
      {:mitigated_risk_cost, :sum,
       field: :estimated_risk_cost, default: 0, query: [filter: expr(status == :mitigated)]}
    ] ++ status_counts(RiskStatus.values())
  end

  defp status_counts(states) do
    for status <- states do
      {status, :count, default: 0, query: [filter: expr(status == ^status)]}
    end
  end

  defp by_status(figures, states), do: Map.new(states, &{&1, Map.fetch!(figures, &1)})

  defp top(query, sort, opts) do
    query
    |> Ash.Query.sort(sort)
    |> Ash.Query.limit(@top)
    |> Ash.Query.load(:estimated_risk_cost)
    |> Ash.read(opts)
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
