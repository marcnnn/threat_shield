defmodule ThreatShield.Periodically do
  @moduledoc """
  Deletes expired invites and API keys every two hours.
  """
  use GenServer

  require Logger

  @interval :timer.hours(2)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(state) do
    schedule_work()
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    report("invites", ThreatShield.Accounts.delete_expired_invites())
    report("API keys", ThreatShield.Accounts.delete_expired_api_keys())
    schedule_work()
    {:noreply, state}
  end

  defp report(_what, %Ash.BulkResult{status: :success}), do: :ok

  defp report(what, %Ash.BulkResult{errors: errors}) do
    Logger.error("Deleting the expired #{what} failed: #{inspect(errors)}")
  end

  defp schedule_work do
    Process.send_after(self(), :work, @interval)
  end
end
