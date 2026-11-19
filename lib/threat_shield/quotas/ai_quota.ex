defmodule ThreatShield.Quotas.AiQuota do
  @moduledoc """
  The `AshThreatShield.AI.Hook` of ThreatShield (configured in `config/config.exs`):
  each suggestion of the AI assistant uses one AI request of the monthly quota of
  the organisation (`QuotaManager.consume/5`). A request above the quota is refused
  with `ThreatShield.Quotas.Errors.QuotaExceeded`.
  """
  @behaviour AshThreatShield.AI.Hook

  alias ThreatShield.Quotas.Errors.QuotaExceeded
  alias ThreatShield.Quotas.QuotaManager

  require Logger

  @quota "ai_requests_per_month"

  @impl true
  def before_ai_request(organisation, user, _kind) do
    case QuotaManager.consume(organisation, user, @quota, 1.0, "AI request") do
      :ok ->
        :ok

      {:error, :quota_exceeded} ->
        Logger.warning("AI quota exceeded for organisation '#{organisation.name}'")
        {:error, QuotaExceeded.exception(quota_type: @quota)}

      {:error, error} ->
        {:error, error}
    end
  end
end
