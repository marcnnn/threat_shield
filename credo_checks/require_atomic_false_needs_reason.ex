defmodule CredoChecks.RequireAtomicFalseNeedsReason do
  use Credo.Check,
    id: "TS002",
    base_priority: :normal,
    category: :design,
    tags: [:ash],
    explanations: [
      check: """
      An update or destroy action with `require_atomic? false` runs its changes in
      Elixir on a record read before, not atomically in the database. Give a change
      an `atomic/3` callback where possible; where it is not, say why in a comment at
      the end of the line or on the line above:

          # the validation reads the system
          require_atomic? false
      """
    ]

  alias CredoChecks.ExplainedLine

  @pattern ~r/\brequire_atomic\?:?\s*false\b/

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> ExplainedLine.unexplained(@pattern)
    |> Enum.map(fn {line_no, _line} ->
      format_issue(issue_meta,
        message: "`require_atomic? false` needs a comment that explains why (same line or above).",
        trigger: "require_atomic?",
        line_no: line_no
      )
    end)
  end
end
