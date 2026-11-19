defmodule CredoChecks.Aliases do
  @moduledoc """
  Resolves module names in the AST of a source file with the `alias` directives of
  the file. The directives of all modules in the file are merged, which is good
  enough for files with one module. Names are strings like `"MyApp.Accounts"`, so
  that the checks create no atoms.
  """

  @doc """
  Returns a map from the short name (an atom such as `:ThreatManagement`) to the full
  name, for `alias A.B`, `alias A.B, as: C` and `alias A.{B, C}`.
  """
  def collect(ast) do
    {_ast, aliases} = Macro.prewalk(ast, %{}, &collect_alias/2)
    aliases
  end

  defp collect_alias({:alias, _, [{:__aliases__, _, parts}]} = node, acc) do
    {node, Map.put(acc, List.last(parts), join(parts))}
  end

  defp collect_alias({:alias, _, [{:__aliases__, _, parts}, opts]} = node, acc)
       when is_list(opts) do
    case Keyword.get(opts, :as) do
      {:__aliases__, _, [short]} -> {node, Map.put(acc, short, join(parts))}
      _ -> {node, Map.put(acc, List.last(parts), join(parts))}
    end
  end

  defp collect_alias(
         {:alias, _, [{{:., _, [{:__aliases__, _, base}, :{}]}, _, children}]} = node,
         acc
       ) do
    acc =
      Enum.reduce(children, acc, fn
        {:__aliases__, _, parts}, acc -> Map.put(acc, List.last(parts), join(base ++ parts))
        _other, acc -> acc
      end)

    {node, acc}
  end

  defp collect_alias(node, acc), do: {node, acc}

  @doc """
  The full name of an `{:__aliases__, _, parts}` node, or `nil` for other nodes.
  """
  def resolve({:__aliases__, _, [first | rest]}, aliases) when is_atom(first) do
    case Map.fetch(aliases, first) do
      {:ok, name} -> Enum.join([name | Enum.map(rest, &Atom.to_string/1)], ".")
      :error -> join([first | rest])
    end
  end

  def resolve(_node, _aliases), do: nil

  @doc """
  The name of a module as `resolve/2` returns it.
  """
  def name(module) when is_atom(module), do: inspect(module)

  defp join(parts), do: Enum.map_join(parts, ".", &Atom.to_string/1)
end
