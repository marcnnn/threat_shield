defmodule ThreatShield.Analytics.RiskAnalytics do
  @moduledoc """
  Analytics functions for risks. The risks need the calculation
  `:estimated_risk_cost` loaded.
  """

  alias ThreatShield.ThreatManagement.Risk

  def sum_up_risk_costs(risks) do
    risks
    |> costs()
    |> Enum.sum()
  end

  def sum_up_risk_costs(risks, status) when is_atom(status) do
    risks
    |> Enum.filter(fn risk -> risk.status == status end)
    |> sum_up_risk_costs()
  end

  def sum_up_risk_costs(risks, states) when is_list(states) do
    risks
    |> Enum.filter(fn risk -> Enum.member?(states, risk.status) end)
    |> sum_up_risk_costs()
  end

  def top_10_severity(risks) do
    risks
    |> Enum.sort_by(& &1.severity, :desc)
    |> Enum.take(10)
  end

  def top_10_risk_costs(risks) do
    risks
    |> Enum.reject(&is_nil(&1.estimated_risk_cost))
    |> Enum.sort_by(& &1.estimated_risk_cost, :desc)
    |> Enum.take(10)
  end

  def max_cost(risks) do
    risks
    |> costs()
    |> max_value()
  end

  def max_frequency(risks) do
    risks
    |> Enum.map(&Risk.frequency_per_year/1)
    |> max_value()
  end

  # internal

  defp costs(risks) do
    risks
    |> Enum.map(& &1.estimated_risk_cost)
    |> Enum.reject(&is_nil/1)
  end

  defp max_value(values) do
    Enum.max(values, &>=/2, fn -> 0 end)
  end
end
