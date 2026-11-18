defmodule ThreatShield.AI do
  @moduledoc """
  The AI assistant: suggests assets, threats, risks, mitigations and attribute
  values.

  A suggestion has three parts, and only the second one needs a language model:

    1. `ThreatShield.AI.Prompts` builds the prompt from the records (pure),
    2. the configured `ThreatShield.AI.Provider` answers it,
    3. this module turns the answer into unsaved records. The user selects some of
       them, and the caller stores them with the normal create actions of
       `ThreatShield.ThreatManagement` (e.g. `create_threat/2` with `actor:`).
  """

  alias ThreatShield.AI.{Prompts, Provider}
  alias ThreatShield.Accounts.Organisation
  alias ThreatShield.DynamicAttribute
  alias ThreatShield.Quotas.QuotaManager
  alias ThreatShield.Scope
  alias ThreatShield.ThreatManagement.{Asset, Mitigation, Risk, Threat}

  require Logger

  @schemas %{assets: Asset, threats: Threat, risks: Risk, mitigations: Mitigation}

  # The changesets of these schemas allow names of up to 60 characters
  @max_name_length 60

  @quota_ai_requests_per_month "ai_requests_per_month"

  @doc """
  Runs an AI task for the scope: checks the quota of the organisation, records the
  usage, and calls `fun`.

  The call blocks until `fun` has returned. Run it in a separate process, for
  example a task of `ThreatShield.TaskSupervisor`.
  """
  def run_task(%Scope{organisation: %Organisation{} = org} = scope, fun)
      when is_function(fun, 0) do
    case QuotaManager.check_quota(org, @quota_ai_requests_per_month, 1) do
      {:ok, :quota_available} ->
        {:ok, _usage} = protocol_quota_usage(scope, "AI request")
        {:ok, fun.()}

      {:error, :quota_exceeded} ->
        Logger.warning("AI quota exceeded for organisation '#{org.name}'")
        {:error, :quota_exceeded}
    end
  end

  @doc """
  Suggests typical values of a dynamic attribute.
  """
  def suggest_values(%DynamicAttribute{} = attribute) do
    {system_prompt, user_prompt} = Prompts.attribute_values(attribute)

    with {:ok, items} <- ask(system_prompt, user_prompt, "suggestions") do
      for %{"value" => value} <- items, do: value
    end
  end

  @doc "Suggests assets of the organisation or of the system of the scope."
  def suggest_assets(%Scope{} = scope), do: scope |> Prompts.assets() |> suggest()

  @doc "Suggests threats of the organisation, the system and/or the asset of the scope."
  def suggest_threats(%Scope{} = scope), do: scope |> Prompts.threats() |> suggest()

  @doc "Suggests risks of a threat."
  def suggest_risks_for_threat(%Scope{} = _scope, %Threat{} = threat),
    do: threat |> Prompts.risks() |> suggest()

  @doc "Suggests mitigations of a risk."
  def suggest_mitigations_for_risk(%Scope{} = _scope, %Risk{} = risk),
    do: risk |> Prompts.mitigations() |> suggest()

  # Returns unsaved records of the kind, or `{:error, reason}`
  defp suggest({kind, system_prompt, user_prompt}) do
    with {:ok, items} <- ask(system_prompt, user_prompt, Atom.to_string(kind)) do
      for %{"name" => name, "description" => description} <- items do
        struct(@schemas[kind],
          name: String.slice(name, 0, @max_name_length),
          description: description
        )
      end
    end
  end

  # Asks the provider and returns the list under `root_key` of the JSON answer. An
  # answer that is not such JSON gives an empty list.
  defp ask(system_prompt, user_prompt, root_key) do
    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_prompt}
    ]

    with {:ok, content} <- Provider.configured().chat(messages, []) do
      case Jason.decode(content) do
        {:ok, %{^root_key => items}} when is_list(items) ->
          {:ok, items}

        other ->
          Logger.error("Unexpected answer of the AI provider: #{inspect(other)}")
          {:ok, []}
      end
    end
  end

  # Quotas

  defp protocol_quota_usage(%Scope{} = scope, message) do
    QuotaManager.add_usage(
      scope.organisation,
      scope.user,
      @quota_ai_requests_per_month,
      1.0,
      message
    )
  end
end
