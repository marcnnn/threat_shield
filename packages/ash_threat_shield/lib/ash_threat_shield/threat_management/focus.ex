defmodule AshThreatShield.ThreatManagement.Focus do
  @moduledoc """
  Reads the organisation of a threat model for its description and the prompts of
  the AI assistant, with the actor. The organisation is a record of the configured
  owner resource (see `AshThreatShield.Owner`); its systems, assets and threats are
  read through the library actions, so the owner resource needs no relationships to
  them.
  """

  alias AshThreatShield.ThreatManagement

  @lists [:systems, :assets, :threats]

  @doc """
  Reads the organisation with the options of an action (`actor:` etc.). An
  organisation that the actor may not read is not found.
  """
  @spec get_organisation(term(), keyword()) :: {:ok, struct()} | {:error, term()}
  def get_organisation(id, opts) do
    Ash.get(AshThreatShield.owner_resource(), id, opts)
  end

  @doc """
  The organisation as `AshThreatShield.ThreatManagement.Description` and
  `AshThreatShield.AI.Prompts` describe it: a map with the `:id`, `:name` and
  `:attributes` of the record, and the given lists of `:systems`, `:assets` and
  `:threats` of the organisation (default: all three), read with the options.
  """
  @spec organisation(struct(), keyword(), [atom()]) :: {:ok, map()} | {:error, term()}
  def organisation(record, opts, lists \\ @lists) do
    base = %{id: record.id, name: record.name, attributes: Map.get(record, :attributes, %{})}

    Enum.reduce_while(lists, {:ok, base}, fn list, {:ok, organisation} ->
      case read(list, record.id, opts) do
        {:ok, entities} -> {:cont, {:ok, Map.put(organisation, list, entities)}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp read(:systems, id, opts), do: ThreatManagement.list_systems(id, opts)
  defp read(:assets, id, opts), do: ThreatManagement.list_assets(id, opts)
  defp read(:threats, id, opts), do: ThreatManagement.list_threats(id, opts)
end
