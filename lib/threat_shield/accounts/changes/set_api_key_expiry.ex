defmodule ThreatShield.Accounts.Changes.SetApiKeyExpiry do
  @moduledoc """
  Sets the expiry of a new API key from the argument `:valid_for_days`, so that no
  caller can create a key that is valid for longer than the action allows.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :valid_for_days) do
      days when is_integer(days) ->
        expires_at = DateTime.add(DateTime.utc_now(), days, :day)
        Ash.Changeset.force_change_attribute(changeset, :expires_at, expires_at)

      _ ->
        changeset
    end
  end
end
