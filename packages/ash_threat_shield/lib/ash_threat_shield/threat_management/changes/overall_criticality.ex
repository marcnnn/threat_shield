defmodule AshThreatShield.ThreatManagement.Changes.OverallCriticality do
  @moduledoc """
  Raises the overall criticality of an asset to at least the average of the
  criticalities of loss, theft and publication, when all three are set.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    values = Enum.map(fields(), &Ash.Changeset.get_attribute(changeset, &1))

    if Enum.any?(values, &is_nil/1) do
      changeset
    else
      overall = Ash.Changeset.get_attribute(changeset, :criticality_overall)
      Ash.Changeset.change_attribute(changeset, :criticality_overall, overall(values, overall))
    end
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    {:atomic,
     %{
       criticality_overall:
         expr(
           if is_nil(^atomic_ref(:criticality_loss)) or is_nil(^atomic_ref(:criticality_theft)) or
                is_nil(^atomic_ref(:criticality_publication)) do
             ^atomic_ref(:criticality_overall)
           else
             if (^atomic_ref(:criticality_loss) + ^atomic_ref(:criticality_theft) +
                   ^atomic_ref(:criticality_publication)) / 3 >
                  coalesce(^atomic_ref(:criticality_overall), 0.0) do
               (^atomic_ref(:criticality_loss) + ^atomic_ref(:criticality_theft) +
                  ^atomic_ref(:criticality_publication)) / 3
             else
               coalesce(^atomic_ref(:criticality_overall), 0.0)
             end
           end
         )
     }}
  end

  defp fields, do: [:criticality_loss, :criticality_theft, :criticality_publication]

  defp overall(values, overall), do: max(Enum.sum(values) / 3, overall || 0.0)
end
