defmodule CredoChecks.ExplainedLine do
  @moduledoc """
  Finds the lines of code that match a pattern and have no explaining comment: a
  comment at the end of the line, or a comment line right above it. Strings, sigils
  and comments do not count as code.
  """

  alias Credo.SourceFile

  @doc """
  Returns `{line_no, line}` for each line whose code matches `pattern` and that has
  no comment on the same line or on the line before.
  """
  def unexplained(%SourceFile{} = source_file, %Regex{} = pattern) do
    code = source_file |> Credo.Code.clean_charlists_strings_sigils_and_comments() |> lines()
    with_comments = source_file |> Credo.Code.clean_charlists_strings_and_sigils() |> lines()
    original = source_file |> SourceFile.source() |> lines()

    code
    |> Enum.with_index()
    |> Enum.filter(fn {line, _index} -> Regex.match?(pattern, line) end)
    |> Enum.reject(fn {_line, index} -> explained?(with_comments, index) end)
    |> Enum.map(fn {_line, index} -> {index + 1, Enum.at(original, index)} end)
  end

  defp explained?(lines, index) do
    String.contains?(Enum.at(lines, index), "#") or
      (index > 0 and lines |> Enum.at(index - 1) |> String.trim_leading() |> comment?())
  end

  defp comment?("#" <> _), do: true
  defp comment?(_line), do: false

  defp lines(text), do: String.split(text, ~r/\R/)
end
