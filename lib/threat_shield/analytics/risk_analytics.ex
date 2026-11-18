defmodule ThreatShield.Analytics.RiskAnalytics do
  @moduledoc """
  Scales of the risk chart of the risk board. The risks need the calculation
  `:estimated_risk_cost` loaded. The figures of the board come from the action
  `ThreatShield.ThreatManagement.ThreatModel.risk_summary`.
  """

  alias ThreatShield.ThreatManagement.Risk

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
