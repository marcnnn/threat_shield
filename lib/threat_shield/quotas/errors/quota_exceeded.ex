defmodule ThreatShield.Quotas.Errors.QuotaExceeded do
  @moduledoc """
  The quota `quota_type` of an organisation does not allow the requested usage.
  """
  use Splode.Error, fields: [:quota_type], class: :invalid

  def message(%{quota_type: quota_type}), do: "the quota #{quota_type} is exceeded"

  @doc """
  Whether an error of an Ash action is or contains a `QuotaExceeded`.
  """
  def exceeded?(%__MODULE__{}), do: true
  def exceeded?(%{errors: errors}) when is_list(errors), do: Enum.any?(errors, &exceeded?/1)
  def exceeded?(_error), do: false
end
