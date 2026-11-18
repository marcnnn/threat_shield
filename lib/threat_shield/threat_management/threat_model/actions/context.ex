defmodule ThreatShield.ThreatManagement.ThreatModel.Actions.Context do
  @moduledoc """
  Reads the organisation and the records in focus with the actor and describes them
  with `ThreatShield.ThreatManagement.Description.threat_model/1`. A record of
  another organisation of the actor is an invalid argument.
  """

  use Ash.Resource.Actions.Implementation

  alias Ash.Error.Action.InvalidArgument
  alias ThreatShield.{Accounts, ThreatManagement}
  alias ThreatShield.ThreatManagement.Description

  @impl true
  def run(input, _opts, context) do
    opts = Ash.Context.to_opts(context)
    args = input.arguments

    with {:ok, organisation} <-
           Accounts.get_organisation(
             args.organisation_id,
             Keyword.put(opts, :load, [:systems, :assets, :threats])
           ),
         {:ok, system} <-
           fetch(:system_id, args, &ThreatManagement.get_system/2, [:assets, :threats], opts),
         {:ok, asset} <- fetch(:asset_id, args, &ThreatManagement.get_asset/2, [:threats], opts),
         {:ok, threat} <- fetch(:threat_id, args, &ThreatManagement.get_threat/2, [:risks], opts),
         {:ok, risk} <-
           fetch(
             :risk_id,
             args,
             &ThreatManagement.get_risk/2,
             [:mitigations, :organisation_id],
             opts
           ),
         :ok <- same_organisation(organisation, system: system, asset: asset),
         :ok <- same_organisation(organisation, threat: threat, risk: risk) do
      {:ok,
       Description.threat_model(%{
         organisation: organisation,
         system: system,
         asset: asset,
         threat: threat,
         risk: risk
       })}
    end
  end

  defp fetch(key, args, get, load, opts) do
    case Map.get(args, key) do
      nil -> {:ok, nil}
      id -> get.(id, Keyword.put(opts, :load, load))
    end
  end

  defp same_organisation(organisation, records) do
    Enum.find_value(records, :ok, fn
      {_name, nil} ->
        nil

      {_name, %{organisation_id: org_id}} when org_id == organisation.id ->
        nil

      {name, _record} ->
        {:error,
         InvalidArgument.exception(
           field: :"#{name}_id",
           message: "does not belong to the organisation"
         )}
    end)
  end
end
