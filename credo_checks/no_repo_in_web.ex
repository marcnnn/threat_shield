defmodule CredoChecks.NoRepoInWeb do
  use Credo.Check,
    id: "TS005",
    base_priority: :high,
    category: :design,
    tags: [:ash, :security],
    explanations: [
      check: """
      The web layer reads and writes data only through the code interfaces of the
      domains, called with the user as `actor:`. A call of an Ecto repo or an Ecto
      query bypasses the policies, validations and changes of the resources.

      Flags calls of modules named `*.Repo` or `Repo`, of `Ecto.Query`,
      `Ecto.Adapters.SQL` and `Ecto.Multi`, and `import`/`require`/`alias` of
      `Ecto.Query`. Mentioning a repo without calling it (for example in the
      options of the LiveDashboard) is allowed.
      """
    ]

  alias CredoChecks.Aliases

  @ecto_modules ["Ecto.Query", "Ecto.Adapters.SQL", "Ecto.Multi"]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    ast = SourceFile.ast(source_file)
    aliases = Aliases.collect(ast)

    {_ast, issues} = Macro.prewalk(ast, [], &walk(&1, &2, aliases, issue_meta))
    Enum.reverse(issues)
  end

  defp walk({directive, meta, [{:__aliases__, _, _} = mod_ast | _]} = node, issues, aliases, im)
       when directive in [:import, :require, :alias] do
    if Aliases.resolve(mod_ast, aliases) == "Ecto.Query" do
      {node, [issue(im, "`#{directive} Ecto.Query`", "#{directive}", meta[:line]) | issues]}
    else
      {node, issues}
    end
  end

  defp walk({{:., _, [{:__aliases__, _, _} = mod_ast, fun]}, meta, _args} = node, issues, aliases, im)
       when is_atom(fun) do
    module = Aliases.resolve(mod_ast, aliases)

    if repo?(module) or module in @ecto_modules do
      name = "#{module}.#{fun}"
      {node, [issue(im, "a call of `#{name}`", to_string(fun), meta[:line]) | issues]}
    else
      {node, issues}
    end
  end

  defp walk(node, issues, _aliases, _im), do: {node, issues}

  defp repo?(nil), do: false
  defp repo?(module), do: module |> String.split(".") |> List.last() == "Repo"

  defp issue(issue_meta, what, trigger, line_no) do
    format_issue(issue_meta,
      message: "The web layer uses #{what}; go through a domain function with `actor:`.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
