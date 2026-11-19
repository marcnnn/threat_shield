defmodule CredoChecks.NoHostReferences do
  use Credo.Check,
    id: "TS004",
    base_priority: :high,
    category: :design,
    tags: [:library],
    param_defaults: [namespaces: [], apps: []],
    explanations: [
      check: """
      The library ash_threat_shield does not know its host: it never references the
      modules of ThreatShield (`ThreatShield.*`, `ThreatShieldWeb.*`) or the
      configuration of the app (`:threat_shield`). The host plugs in through the
      seams of `config :ash_threat_shield`.
      """,
      params: [
        namespaces: "Top-level modules that must not be referenced, e.g. `[ThreatShield]`.",
        apps: "OTP applications whose atoms must not appear, e.g. `[:threat_shield]`."
      ]
    ]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    namespaces =
      params |> Params.get(:namespaces, __MODULE__) |> Enum.map(&(&1 |> Module.split() |> hd()))

    apps = Params.get(params, :apps, __MODULE__)

    (module_issues(source_file, namespaces, issue_meta) ++
       app_issues(source_file, apps, issue_meta))
    |> Enum.sort_by(& &1.line_no)
  end

  defp module_issues(source_file, namespaces, issue_meta) do
    {_ast, issues} =
      source_file
      |> SourceFile.ast()
      |> Macro.prewalk([], fn
        {:__aliases__, meta, [first | _] = parts} = node, issues when is_atom(first) ->
          if Atom.to_string(first) in namespaces do
            name = Enum.map_join(parts, ".", &Atom.to_string/1)
            {node, [issue(issue_meta, "the module `#{name}`", name, meta[:line]) | issues]}
          else
            {node, issues}
          end

        node, issues ->
          {node, issues}
      end)

    issues
  end

  # atoms carry no line in the AST, so they are searched in the code without strings
  # and comments
  defp app_issues(source_file, apps, issue_meta) do
    lines =
      source_file
      |> Credo.Code.clean_charlists_strings_sigils_and_comments()
      |> String.split(~r/\R/)
      |> Enum.with_index(1)

    for {line, line_no} <- lines,
        app <- apps,
        Regex.match?(~r/(?<![\w:]):#{app}\b/, line) do
      issue(issue_meta, "the application `:#{app}`", ":#{app}", line_no)
    end
  end

  defp issue(issue_meta, what, trigger, line_no) do
    format_issue(issue_meta,
      message: "The library references #{what} of its host.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
