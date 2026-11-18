defmodule ThreatShield.ThreatManagement.ThreatModel.Actions.Suggest do
  @moduledoc """
  Asks the AI assistant for new entities of the kind `opts[:kind]` (`:assets`,
  `:threats`, `:risks` or `:mitigations`) and returns them unsaved.

  The policy of the action has checked the right to create such entities. The action
  reads the records in focus with the actor, uses one AI request of the quota of the
  organisation (`ThreatShield.Quotas.QuotaManager.consume/5`), and only then calls the
  language model.
  """

  use Ash.Resource.Actions.Implementation

  alias Ash.Error.Action.InvalidArgument
  alias ThreatShield.{Accounts, AI, ThreatManagement}
  alias ThreatShield.Quotas.Errors.QuotaExceeded
  alias ThreatShield.Quotas.QuotaManager
  alias ThreatShield.Scope

  require Logger

  @quota "ai_requests_per_month"

  @impl true
  def run(input, opts, context) do
    ash_opts = Ash.Context.to_opts(context)
    kind = Keyword.fetch!(opts, :kind)

    with {:ok, scope, subject} <- focus(kind, input.arguments, ash_opts),
         :ok <- consume_quota(scope),
         suggestions when is_list(suggestions) <- suggest(kind, scope, subject) do
      {:ok, suggestions}
    end
  end

  defp focus(kind, args, opts) when kind in [:assets, :threats] do
    with {:ok, organisation} <-
           Accounts.get_organisation(
             args.organisation_id,
             Keyword.put(opts, :load, [:systems, :assets, :threats])
           ),
         {:ok, system} <-
           fetch(args[:system_id], &ThreatManagement.get_system/2, [:assets, :threats], opts),
         {:ok, asset} <-
           fetch(args[:asset_id], &ThreatManagement.get_asset/2, [:system, :threats], opts),
         :ok <- same_organisation(organisation, system_id: system, asset_id: asset) do
      user = opts[:actor]
      {:ok, Scope.for(user, organisation, system: system, asset: asset), nil}
    end
  end

  defp focus(:risks, args, opts) do
    with {:ok, threat} <-
           ThreatManagement.get_threat(
             args.threat_id,
             Keyword.put(opts, :load, risks: :mitigations, organisation: [:systems])
           ) do
      {:ok, Scope.for(opts[:actor], threat.organisation, threat: threat), threat}
    end
  end

  defp focus(:mitigations, args, opts) do
    with {:ok, risk} <-
           ThreatManagement.get_risk(
             args.risk_id,
             Keyword.put(opts, :load, [:mitigations, threat: [:system, organisation: [:systems]]])
           ) do
      {:ok, Scope.for(opts[:actor], risk.threat.organisation, threat: risk.threat), risk}
    end
  end

  # The prompts use the organisation of a system or an asset
  defp fetch(nil, _get, _load, _opts), do: {:ok, nil}

  defp fetch(id, get, load, opts),
    do: get.(id, Keyword.put(opts, :load, load ++ [organisation: [:systems]]))

  defp same_organisation(organisation, records) do
    Enum.find_value(records, :ok, fn
      {_field, nil} ->
        nil

      {_field, %{organisation_id: org_id}} when org_id == organisation.id ->
        nil

      {field, _record} ->
        {:error,
         InvalidArgument.exception(field: field, message: "does not belong to the organisation")}
    end)
  end

  defp consume_quota(%Scope{organisation: organisation, user: user}) do
    case QuotaManager.consume(organisation, user, @quota, 1.0, "AI request") do
      :ok ->
        :ok

      {:error, :quota_exceeded} ->
        Logger.warning("AI quota exceeded for organisation '#{organisation.name}'")
        {:error, QuotaExceeded.exception(quota_type: @quota)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp suggest(:assets, scope, _subject), do: AI.suggest_assets(scope)
  defp suggest(:threats, scope, _subject), do: AI.suggest_threats(scope)
  defp suggest(:risks, scope, threat), do: AI.suggest_risks_for_threat(scope, threat)
  defp suggest(:mitigations, scope, risk), do: AI.suggest_mitigations_for_risk(scope, risk)
end
