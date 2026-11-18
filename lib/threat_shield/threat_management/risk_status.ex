defmodule ThreatShield.ThreatManagement.RiskStatus do
  @moduledoc """
  The status of a risk. Stored as a string.
  """
  use Ash.Type.Enum,
    values: [
      identified: "The risk is known but not assessed yet.",
      assessed: "The cost, probability and severity of the risk are assessed.",
      mitigated: "Mitigations reduce the risk sufficiently.",
      accepted: "The risk is accepted without further mitigation."
    ]

  @doc """
  The states of a risk that is not mitigated.
  """
  def unmitigated, do: values() -- [:mitigated]
end
