defmodule AshThreatShield.ThreatManagement.ThreatModel.Actions.Suggest do
  @moduledoc """
  Asks the AI assistant for new entities of the kind `opts[:kind]` (`:assets`,
  `:threats`, `:risks` or `:mitigations`) and returns them unsaved.

  The policy of the action has checked the right to create such entities. The action
  reads the records in focus with the actor, calls the configured
  `AshThreatShield.AI.Hook` (e.g. the quota of the host application), and only then
  calls the language model.
  """

  use Ash.Resource.Actions.Implementation

  alias Ash.Error.Action.InvalidArgument
  alias AshThreatShield.AI
  alias AshThreatShield.ThreatManagement
  alias AshThreatShield.ThreatManagement.Focus

  @impl true
  def run(input, opts, context) do
    ash_opts = Ash.Context.to_opts(context)
    kind = Keyword.fetch!(opts, :kind)

    with {:ok, record, focus, subject} <- focus(kind, input.arguments, ash_opts),
         :ok <- AI.Hook.run(record, ash_opts[:actor], kind),
         suggestions when is_list(suggestions) <- suggest(kind, focus, subject) do
      {:ok, suggestions}
    end
  end

  # Returns the record of the organisation (for the hook), the focus of the prompt
  # and the threat or risk that the suggestions are for
  defp focus(kind, args, opts) when kind in [:assets, :threats] do
    with {:ok, record} <- Focus.get_organisation(args.organisation_id, opts),
         {:ok, organisation} <- Focus.organisation(record, opts),
         {:ok, system} <-
           fetch(args[:system_id], &ThreatManagement.get_system/2, [:assets, :threats], opts),
         {:ok, asset} <-
           fetch(args[:asset_id], &ThreatManagement.get_asset/2, [:system, :threats], opts),
         :ok <- same_organisation(organisation, system_id: system, asset_id: asset) do
      {:ok, record, %{organisation: organisation, system: system, asset: asset}, nil}
    end
  end

  defp focus(:risks, args, opts) do
    with {:ok, threat} <-
           ThreatManagement.get_threat(args.threat_id, Keyword.put(opts, :load, [:risks])),
         {:ok, record, organisation} <- organisation(threat.organisation_id, opts) do
      {:ok, record, %{organisation: organisation, threat: threat}, threat}
    end
  end

  defp focus(:mitigations, args, opts) do
    with {:ok, risk} <-
           ThreatManagement.get_risk(
             args.risk_id,
             Keyword.put(opts, :load, [:mitigations, threat: [:system]])
           ),
         {:ok, record, organisation} <- organisation(risk.threat.organisation_id, opts) do
      {:ok, record, %{organisation: organisation, threat: risk.threat}, risk}
    end
  end

  # The prompts of risks and mitigations describe the organisation with its systems
  defp organisation(id, opts) do
    with {:ok, record} <- Focus.get_organisation(id, opts),
         {:ok, organisation} <- Focus.organisation(record, opts, [:systems]) do
      {:ok, record, organisation}
    end
  end

  defp fetch(nil, _get, _load, _opts), do: {:ok, nil}
  defp fetch(id, get, load, opts), do: get.(id, Keyword.put(opts, :load, load))

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

  defp suggest(:assets, focus, _subject), do: AI.suggest_assets(focus)
  defp suggest(:threats, focus, _subject), do: AI.suggest_threats(focus)
  defp suggest(:risks, focus, threat), do: AI.suggest_risks_for_threat(focus, threat)
  defp suggest(:mitigations, focus, risk), do: AI.suggest_mitigations_for_risk(focus, risk)
end
