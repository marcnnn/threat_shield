defmodule AshThreatShield.AI.Prompts do
  @moduledoc """
  Builds the prompts of the AI assistant. The functions are pure: they read only the
  given records and need no language model, so other clients (e.g. a chat agent over
  MCP) can use the same text.

  Each suggestion function returns `{kind, system_prompt, user_prompt}`, where `kind`
  is the plural of the entities that are asked for (`:assets`, `:threats`, `:risks`,
  `:mitigations`), which is also the root key of the JSON answer.
  """

  alias AshThreatShield.DynamicAttribute
  alias AshThreatShield.ThreatManagement.{Asset, Description, Risk, System, Threat}

  # The explanation of each kind of entity that is sent with a request
  @info %{
    assets: "  Assets are valuable resources or data, that need to be protected.\n",
    threats:
      "Threats are any potential event or action that can compromise the security of a system, organisation, or individual. Threats are not the negative outcome, i.e. not the loss, damage, or harm resulting from the exploitation of vulnerabilities by threats.",
    risks:
      "Risks are the potential negative outcome: loss, damage, or harm resulting from the exploitation of vulnerabilities by threats.\n",
    mitigations:
      "Mitigations are strategies and measures put in place to mitigate the risks of a particular threat.\n"
  }

  @doc """
  The system prompt with the context of the organisation (see
  `AshThreatShield.ThreatManagement.Focus.organisation/3`). It needs its `:systems`.
  """
  def job_description(%{name: _} = organisation) do
    """
    You are a threat modelling assistant at "#{organisation.name}".
    #{Description.organisation(organisation)}
    """
  end

  @doc """
  Asks for typical values of an attribute. The answer has the root key
  `"suggestions"`.
  """
  def attribute_values(%DynamicAttribute{name: name, description: description}) do
    system_prompt = """
    You are a software engineer. Your answer is in valid JSON format like so {"suggestions": [{"value": _}, _ ]}.
    """

    user_prompt = """
    Suggest 10 examples of typical values for an attribute with the name "#{name}". The user-facing description of the attribute is "#{description}".
    """

    {system_prompt, user_prompt}
  end

  @doc """
  Asks for assets of the organisation or of the system of the focus. The
  organisation needs its `:assets`, the system its `:assets`.
  """
  def assets(%{organisation: organisation} = focus) do
    case Map.get(focus, :system) do
      %System{} = system ->
        suggestion(:assets, organisation, system.assets,
          info:
            "  Assets are valuable resources or data for a particular system, that need to be protected.\n",
          focus: ~s( The assets should be specific to the system "#{system.name}".)
        )

      nil ->
        suggestion(:assets, organisation, Map.get(organisation, :assets))
    end
  end

  @doc """
  Asks for threats of the organisation, the system and/or the asset of the focus.
  The most specific of them needs its `:threats`.
  """
  def threats(%{organisation: organisation} = focus) do
    # order is important here, as the most specific focus should be matched first
    case {Map.get(focus, :asset), Map.get(focus, :system)} do
      {%Asset{} = asset, %System{} = system} ->
        suggestion(:threats, organisation, asset.threats,
          focus:
            " The threats should be specific to the system the system '#{system.name}'  and the asset '#{asset.name}'"
        )

      {%Asset{} = asset, nil} ->
        suggestion(:threats, organisation, asset.threats,
          focus: " The threats should be specific to the asset '#{asset.name}'"
        )

      {nil, %System{} = system} ->
        suggestion(:threats, organisation, system.threats,
          focus: " The threats should be specific to the system '#{system.name}'"
        )

      {nil, nil} ->
        suggestion(:threats, organisation, Map.get(organisation, :threats))
    end
  end

  @doc """
  Asks for risks of a threat of the organisation. The threat needs its `:risks`.
  """
  def risks(organisation, %Threat{} = threat) do
    suggestion(:risks, organisation, threat.risks,
      focus: ~s( The risks should relate exclusively to the threat "#{threat.name}".)
    )
  end

  @doc """
  Asks for mitigations of a risk of the organisation. The risk needs its
  `:mitigations` and its `:threat` with the `:system`.
  """
  def mitigations(organisation, %Risk{} = risk) do
    system_exclusivity =
      if is_nil(risk.threat.system) do
        ""
      else
        """
        The only relvant system in this context is "#{risk.threat.system.name}".
        """
      end

    suggestion(:mitigations, organisation, risk.mitigations,
      focus:
        ~s( The mitigations should relate exclusively to the risk "#{risk.name}" and the threat "#{risk.threat.name}".),
      extra: system_exclusivity
    )
  end

  # Asks for five suggestions of the given kind.
  #
  # `existing` are the entities of this kind that are known already. Options:
  #   * `:info` - replaces the default explanation of the kind
  #   * `:focus` - a sentence that narrows the assignment, e.g. to one system
  #   * `:extra` - a further part at the end of the prompt
  defp suggestion(kind, organisation, existing, opts \\ []) do
    plural = Atom.to_string(kind)
    # a relationship that was not loaded counts as empty
    existing = if is_list(existing), do: existing, else: []

    existing_names =
      if Enum.empty?(existing) do
        ""
      else
        "I already know about the following #{plural}:\n\n" <>
          Enum.map_join(existing, "\n", fn e -> e.name end)
      end

    assignment =
      "Please suggest five additional #{plural} that are different from the existing ones." <>
        Keyword.get(opts, :focus, "") <> "\n"

    user_prompt =
      ([
         response_format(plural),
         Keyword.get(opts, :info, @info[kind]),
         existing_names,
         assignment
       ] ++ List.wrap(opts[:extra]))
      |> Enum.join(" ")

    {kind, job_description(organisation), user_prompt}
  end

  defp response_format(plural) do
    """
    Your response should comprise five response items, each item has a name and a description. The name should be up to 40 characters, the descriptions should be between 400 and 1000 characters long. The result must be valid JSON in this format:

    {"#{plural}": [{"name": _, "description": _}, _ ]}
    """
  end
end
