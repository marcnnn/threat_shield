defmodule ThreatShield.Quotas.QuotaManager do
  @moduledoc """
  Responsible for managing quotas for organisations and users.
  """

  alias ThreatShield.Quotas.QuotaUsage
  alias ThreatShield.Accounts.Organisation

  def get_usage(%Organisation{} = org, quota_type) do
    QuotaUsage
    |> Ash.Query.for_read(
      :get_usage,
      %{
        organisation_id: org.id,
        quota_type: to_string(quota_type),
        since: start_time(quota_type)
      },
      authorize?: false
    )
    |> Ash.sum!(:amount, authorize?: false)
    |> Kernel.||(0.0)
  end

  def check_quota(%Organisation{} = org, quota_type, amount \\ 1.0) do
    already_used = get_usage(org, quota_type)
    quota = (org.quotas || %{})[quota_type] || 0.0

    if already_used + amount > quota do
      {:error, :quota_exceeded}
    else
      {:ok, :quota_available}
    end
  end

  def add_usage(%Organisation{} = org, %{id: user_id}, quota_type, amount, message \\ nil) do
    QuotaUsage
    |> Ash.Changeset.for_create(
      :create,
      %{
        organisation_id: org.id,
        user_id: user_id,
        quota_type: to_string(quota_type),
        amount: amount,
        message: message
      },
      authorize?: false
    )
    |> Ash.create()
  end

  defp start_time(quota_type) when is_atom(quota_type) do
    case quota_type do
      :ai_requests_per_month -> Timex.shift(Timex.now(), months: -1)
      _ -> Timex.beginning_of_day(Timex.now())
    end
  end

  defp start_time(quota_type) when is_binary(quota_type) do
    start_time(String.to_existing_atom(quota_type))
  end
end
