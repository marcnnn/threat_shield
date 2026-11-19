defmodule AshThreatShield.ThreatManagement.Description do
  @moduledoc """
  Describes a threat model in plain text: the organisation with its systems, and
  optionally the system, asset, threat and risk in focus with the entities that are
  known already.

  The functions are pure: they read only the given records. The built-in AI
  assistant uses this text as the context of its prompts (`AshThreatShield.AI.Prompts`),
  and the generic action `ThreatModel.context` returns it to chat agents, which do the
  reasoning themselves.
  """

  alias AshThreatShield.Owner
  alias AshThreatShield.ThreatManagement.System

  @typedoc """
  The records in focus. The organisation is required: a map or record with `:name`,
  `:attributes` and `:systems` (see `AshThreatShield.ThreatManagement.Focus`).
  The lists of known entities come from the most specific record, so load
  `:assets` and `:threats` on the organisation, system or asset, `:risks` on the
  threat and `:mitigations` on the risk.
  """
  @type focus :: %{
          required(:organisation) => map(),
          optional(:system) => struct() | nil,
          optional(:asset) => struct() | nil,
          optional(:threat) => struct() | nil,
          optional(:risk) => struct() | nil
        }

  @doc """
  Describes the organisation, its properties and its systems. This is the context
  of every prompt of the AI assistant.
  """
  def organisation(%{name: name} = organisation) do
    attributes = Map.get(organisation, :attributes)

    name_string = """
    The name of the organisation is "#{name}".
    """

    attribute_values =
      "The organisation has the following properties:\n" <>
        properties(attributes)

    attribute_description =
      "The organisation properties have the following user-facing descriptions:\n" <>
        property_descriptions(Owner.attributes_config())

    system_description =
      "It has the following systems:\n" <>
        (organisation |> loaded(:systems) |> Enum.map_join("\n", &system/1))

    [name_string, attribute_values, attribute_description, system_description]
    |> Enum.join(" ")
  end

  @doc """
  Describes a system with its properties.
  """
  def system(%{name: name, description: description, attributes: attributes}) do
    name_string = """
    The name of the system is "#{name}". It can be described as follows: "#{description}".
    """

    attribute_values =
      "The system has the following properties:\n" <> properties(attributes)

    attribute_description =
      "The system properties have the following user-facing descriptions:\n" <>
        property_descriptions(System.attributes_config())

    [name_string, attribute_values, attribute_description]
    |> Enum.join(" ")
  end

  @doc """
  Describes the threat model around the records in focus, see `t:focus/0`.
  """
  @spec threat_model(focus()) :: String.t()
  def threat_model(%{organisation: organisation} = focus) do
    [
      section("Organisation", organisation(organisation)),
      focus[:system] && section("System in focus", system(focus.system)),
      focus[:asset] && section("Asset in focus", asset(focus.asset)),
      focus[:threat] && section("Threat in focus", threat(focus.threat)),
      focus[:risk] && section("Risk in focus", risk(focus.risk))
      | known_entities(focus)
    ]
    |> Enum.reject(&(&1 in [nil, false]))
    |> Enum.join("\n")
  end

  defp asset(asset) do
    """
    The name of the asset is "#{asset.name}". It can be described as follows: "#{asset.description}".
    Criticality from 0 to 5: loss #{value(asset.criticality_loss)}, theft #{value(asset.criticality_theft)}, publication #{value(asset.criticality_publication)}, overall #{value(asset.criticality_overall)}.
    """
  end

  defp threat(threat) do
    """
    The name of the threat is "#{threat.name}". It can be described as follows: "#{threat.description}".
    """
  end

  defp risk(risk) do
    """
    The name of the risk is "#{risk.name}". It can be described as follows: "#{risk.description}".
    Status: #{value(risk.status)}. Estimated cost: #{value(risk.estimated_cost)}. Probability per year: #{value(risk.probability)}. Severity from 0 to 5: #{value(risk.severity)}.
    """
  end

  # The entities that are known for the most specific record in focus
  defp known_entities(focus) do
    cond do
      focus[:risk] ->
        [known("Mitigations of the risk", loaded(focus.risk, :mitigations))]

      focus[:threat] ->
        [known("Risks of the threat", loaded(focus.threat, :risks))]

      focus[:asset] ->
        [known("Threats of the asset", loaded(focus.asset, :threats))]

      focus[:system] ->
        [
          known("Assets of the system", loaded(focus.system, :assets)),
          known("Threats of the system", loaded(focus.system, :threats))
        ]

      true ->
        [
          known("Assets of the organisation", loaded(focus.organisation, :assets)),
          known("Threats of the organisation", loaded(focus.organisation, :threats))
        ]
    end
  end

  defp known(title, []), do: section(title, "None yet.\n")

  defp known(title, entities) do
    section(title, Enum.map_join(entities, "", &"- #{&1.name} (id #{&1.id})\n"))
  end

  defp section(title, text), do: "## #{title}\n\n#{text}"

  defp properties(attributes) do
    (attributes || %{})
    |> Enum.filter(fn {_, val} -> val != "" end)
    |> Enum.map_join("\n", fn {key, val} -> ~s{"#{key}: ", "#{val}"} end)
  end

  defp property_descriptions(config) do
    Enum.map_join(config, "\n", fn d -> ~s{"#{d.name}: ", "#{d.description}"} end)
  end

  defp value(nil), do: "unknown"
  defp value(value), do: to_string(value)

  # A relationship that was not loaded counts as empty
  defp loaded(record, relationship) do
    case Map.get(record, relationship) do
      list when is_list(list) -> list
      _ -> []
    end
  end
end
