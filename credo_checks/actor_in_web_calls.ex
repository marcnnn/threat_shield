defmodule CredoChecks.ActorInWebCalls do
  use Credo.Check,
    id: "TS003",
    base_priority: :high,
    category: :warning,
    tags: [:ash, :security],
    param_defaults: [domains: [], public: []],
    explanations: [
      check: """
      Every call on a user path passes the user as `actor:`, so that the policies
      apply. In the web layer, a call of a code interface of a domain, of an Ash
      action function (`Ash.read/2`, `Ash.get!/3`, ...) or of an AshPhoenix form
      builder (`AshPhoenix.Form.for_create/3`, ...) must have `actor:` (or `scope:`)
      in its options:

          ThreatManagement.get_threat!(id, actor: user, load: [:risks])

      For `Ash.*` calls, an `actor:` in the query or changeset built in the same
      pipeline counts too. Options passed in a variable whose name ends in `opts` or
      `options` are not checked.

      Actions that need no actor (sign in, password reset, confirmation) are listed
      in the parameter `public` as `{module, :function}`.
      """,
      params: [
        domains: "The domain modules whose code interfaces are checked.",
        public: "`{module, :function}` calls that need no actor; a `!` is ignored."
      ]
    ]

  alias CredoChecks.Aliases

  @ash_actions ~w(read read! read_one read_one! read_first read_first! get get! create create!
    update update! destroy destroy! bulk_create bulk_create! bulk_update bulk_update!
    bulk_destroy bulk_destroy! load load! count count! exists exists? sum sum! list list!
    max max! min min! avg avg! first first! aggregate aggregate! calculate calculate!
    run_action run_action! can can? stream!)a

  @form_builders ~w(for_create for_update for_destroy for_read for_action)a

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    domains = params |> Params.get(:domains, __MODULE__) |> Enum.map(&Aliases.name/1)
    public = params |> Params.get(:public, __MODULE__) |> Enum.map(&normalize/1)
    ast = SourceFile.ast(source_file)
    aliases = Aliases.collect(ast)
    config = %{domains: domains, public: public, aliases: aliases}

    {_ast, {issues, _handled}} =
      Macro.prewalk(ast, {[], MapSet.new()}, &walk(&1, &2, config, issue_meta))

    Enum.reverse(issues)
  end

  # A call at the end of a pipe also sees the left side of the pipe.
  defp walk({:|>, _, [lhs, {{:., _, [_mod, _fun]}, meta, args} = call]} = node, acc, config, im) do
    {issues, handled} = acc

    case target(call, config) do
      nil ->
        {node, acc}

      kind ->
        handled = MapSet.put(handled, meta)
        extra = if kind == :ash, do: [lhs], else: []
        {node, {check(call, args ++ extra, kind, issues, im), handled}}
    end
  end

  defp walk({{:., _, [_mod, _fun]}, meta, args} = call, {issues, handled} = acc, config, im)
       when is_list(args) do
    if MapSet.member?(handled, meta) do
      {call, acc}
    else
      case target(call, config) do
        nil -> {call, acc}
        kind -> {call, {check(call, args, kind, issues, im), handled}}
      end
    end
  end

  defp walk(node, acc, _config, _im), do: {node, acc}

  # `:{}` is the multi-alias `alias A.{B, C}`, not a call
  defp target({{:., _, [mod_ast, fun]}, _, _}, config) when is_atom(fun) and fun != :{} do
    module = Aliases.resolve(mod_ast, config.aliases)

    if module && {module, normalize_fun(fun)} not in config.public do
      kind(module, fun, config.domains)
    end
  end

  defp target(_call, _config), do: nil

  defp kind(module, fun, domains) do
    cond do
      module in domains -> :domain
      module == "Ash" and fun in @ash_actions -> :ash
      module == "AshPhoenix.Form" and fun in @form_builders -> :form
      true -> nil
    end
  end

  defp check({{:., _, [mod_ast, fun]}, meta, _}, args, _kind, issues, issue_meta) do
    if Enum.any?(args, &carries_actor?/1) or Enum.any?(args, &opts_variable?/1) do
      issues
    else
      name = "#{Macro.to_string(mod_ast)}.#{fun}"

      issue =
        format_issue(issue_meta,
          message: "`#{name}` is called without `actor:`.",
          trigger: to_string(fun),
          line_no: meta[:line]
        )

      [issue | issues]
    end
  end

  # a keyword list (anywhere in the argument, e.g. in a pipeline) with :actor or :scope
  defp carries_actor?(ast) do
    {_ast, found?} =
      Macro.prewalk(ast, false, fn
        node, true -> {node, true}
        {key, _value} = node, false when key in [:actor, :scope] -> {node, true}
        node, false -> {node, false}
      end)

    found?
  end

  defp opts_variable?({name, _, context}) when is_atom(name) and is_atom(context) do
    name = Atom.to_string(name)
    String.ends_with?(name, "opts") or String.ends_with?(name, "options")
  end

  defp opts_variable?(_ast), do: false

  defp normalize({module, fun}), do: {Aliases.name(module), normalize_fun(fun)}

  defp normalize_fun(fun), do: fun |> Atom.to_string() |> String.trim_trailing("!")
end
