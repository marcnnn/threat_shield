defmodule AshThreatShield.ThreatManagement.MitigationStatus do
  @moduledoc """
  The status of a mitigation. Stored as a string.
  """
  use Ash.Type.Enum,
    values: [
      open: "The mitigation is planned.",
      in_progress: "The mitigation is being implemented.",
      implemented: "The mitigation is implemented.",
      verified: "The mitigation is implemented and its effect is verified.",
      failed: "The mitigation failed.",
      deferred: "The mitigation is postponed.",
      obsolete: "The mitigation is not needed any more."
    ]

  @doc """
  The states of an implemented mitigation.
  """
  def implemented, do: [:implemented, :verified]
end
