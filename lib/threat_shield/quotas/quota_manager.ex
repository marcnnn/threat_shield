defmodule ThreatShield.Quotas.QuotaManager do
  @moduledoc """
  Responsible for managing quotas for organisations and users.
  """

  # Quota bookkeeping is a system operation: it counts and records the usage of an
  # organisation for any member, so it runs without authorization.

  alias ThreatShield.Accounts.Organisation
  alias ThreatShield.Quotas
  alias ThreatShield.Quotas.Errors.QuotaExceeded

  @doc """
  Returns `{:ok, amount}` with the usage of the quota in its current period.
  """
  def get_usage(%Organisation{} = org, quota_type) do
    # system operation, see the comment at the top of the module
    opts = [authorize?: false]

    org.id
    |> Quotas.query_to_quota_usage(to_string(quota_type), start_time(quota_type), opts)
    |> Ash.sum(:amount, opts)
    |> case do
      {:ok, amount} -> {:ok, amount || 0.0}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Returns `{:ok, :quota_available}` if the quota of the organisation allows the usage
  `amount`, `{:error, :quota_exceeded}` if not.
  """
  def check_quota(%Organisation{} = org, quota_type, amount \\ 1.0) do
    with {:ok, already_used} <- get_usage(org, quota_type) do
      quota = (org.quotas || %{})[quota_type] || 0.0

      if already_used + amount > quota do
        {:error, :quota_exceeded}
      else
        {:ok, :quota_available}
      end
    end
  end

  @doc """
  Records the usage `amount` of the quota for the user if the quota of the
  organisation allows it, and returns `:ok`, or `{:error, :quota_exceeded}`. The
  check and the record are one transaction with a lock on the organisation, so
  concurrent requests cannot exceed the quota together.
  """
  def consume(%Organisation{} = org, user, quota_type, amount \\ 1.0, message \\ nil) do
    %{
      organisation_id: org.id,
      user_id: user && user.id,
      quota_type: to_string(quota_type),
      amount: amount,
      message: message
    }
    # system operation, see the comment at the top of the module
    |> Quotas.consume_quota(authorize?: false)
    |> case do
      :ok ->
        :ok

      {:error, error} ->
        if QuotaExceeded.exceeded?(error), do: {:error, :quota_exceeded}, else: {:error, error}
    end
  end

  def add_usage(%Organisation{} = org, %{id: user_id}, quota_type, amount, message \\ nil) do
    Quotas.create_quota_usage(
      %{
        organisation_id: org.id,
        user_id: user_id,
        quota_type: to_string(quota_type),
        amount: amount,
        message: message
      },
      # system operation, see the comment at the top of the module
      authorize?: false
    )
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
