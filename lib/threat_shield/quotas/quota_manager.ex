defmodule ThreatShield.Quotas.QuotaManager do
  @moduledoc """
  Responsible for managing quotas for organisations and users.
  """

  # Quota bookkeeping is a system operation: it counts and records the usage of an
  # organisation for any member, so it runs without authorization.

  alias ThreatShield.Quotas.Errors.QuotaExceeded
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

  @doc """
  Records the usage `amount` of the quota for the user if the quota of the
  organisation allows it, and returns `:ok`, or `{:error, :quota_exceeded}`. The
  check and the record are one transaction with a lock on the organisation, so
  concurrent requests cannot exceed the quota together.
  """
  def consume(%Organisation{} = org, user, quota_type, amount \\ 1.0, message \\ nil) do
    QuotaUsage
    |> Ash.ActionInput.for_action(
      :consume,
      %{
        organisation_id: org.id,
        user_id: user && user.id,
        quota_type: to_string(quota_type),
        amount: amount,
        message: message
      },
      authorize?: false
    )
    |> Ash.run_action()
    |> case do
      :ok ->
        :ok

      {:error, error} ->
        if QuotaExceeded.exceeded?(error), do: {:error, :quota_exceeded}, else: {:error, error}
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
