defmodule ThreatShield.ThreatManagement.Changes.SetImplemented do
  @moduledoc """
  Sets `is_implemented` of a mitigation from its status.
  """
  use Ash.Resource.Change

  alias ThreatShield.ThreatManagement.MitigationStatus

  @impl true
  def change(changeset, _opts, _context) do
    implemented? =
      Ash.Changeset.get_attribute(changeset, :status) in MitigationStatus.implemented()

    Ash.Changeset.force_change_attribute(changeset, :is_implemented, implemented?)
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    states = MitigationStatus.implemented()
    # false, not NULL, for a missing status (the column is NOT NULL)
    {:atomic,
     %{
       is_implemented:
         expr(not is_nil(^atomic_ref(:status)) and ^atomic_ref(:status) in ^states)
     }}
  end
end
