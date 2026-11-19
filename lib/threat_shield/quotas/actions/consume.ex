defmodule ThreatShield.Quotas.Actions.Consume do
  @moduledoc """
  Records a usage of a quota if the quota of the organisation allows it. Runs in a
  transaction and locks the row of the organisation first, so that concurrent
  requests of the same organisation are counted one after the other and cannot
  exceed the quota together.
  """

  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Ash.Error.Query.NotFound
  alias ThreatShield.Accounts.Organisation
  alias ThreatShield.Quotas.Errors.QuotaExceeded
  alias ThreatShield.Quotas.QuotaManager

  @impl true
  def run(input, _opts, _context) do
    args = input.arguments

    with {:ok, organisation} <- lock_organisation(args.organisation_id),
         :ok <- available(organisation, args.quota_type, args.amount),
         {:ok, _usage} <-
           QuotaManager.add_usage(
             organisation,
             %{id: args[:user_id]},
             args.quota_type,
             args.amount,
             args[:message]
           ) do
      :ok
    end
  end

  # Quota bookkeeping is a system operation (see `ThreatShield.Quotas.QuotaManager`)
  defp lock_organisation(id) do
    Organisation
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    # system operation without a user, see the comment above
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Organisation{} = organisation} -> {:ok, organisation}
      {:ok, nil} -> {:error, NotFound.exception(resource: Organisation)}
      {:error, error} -> {:error, error}
    end
  end

  defp available(organisation, quota_type, amount) do
    case QuotaManager.check_quota(organisation, quota_type, amount) do
      {:ok, :quota_available} -> :ok
      {:error, :quota_exceeded} -> {:error, QuotaExceeded.exception(quota_type: quota_type)}
      {:error, error} -> {:error, error}
    end
  end
end
