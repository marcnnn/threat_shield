defmodule CredoChecks.AuthorizeFalseNeedsReason do
  use Credo.Check,
    id: "TS001",
    base_priority: :high,
    category: :warning,
    tags: [:ash, :security],
    explanations: [
      check: """
      `authorize?: false` skips the policies. It is allowed only for system
      operations without a user (cleanup jobs, quota bookkeeping, the lookups inside
      policy checks, ...), and each use says why in a comment at the end of the line
      or on the line above:

          # quota bookkeeping is a system operation without a user
          |> Ash.read_one(authorize?: false)

      On a user path, pass the user as `actor:` instead.
      """
    ]

  alias CredoChecks.ExplainedLine

  @pattern ~r/\bauthorize\?:\s*false\b/

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> ExplainedLine.unexplained(@pattern)
    |> Enum.map(fn {line_no, _line} ->
      format_issue(issue_meta,
        message: "`authorize?: false` needs a comment that explains why (same line or above).",
        trigger: "authorize?:",
        line_no: line_no
      )
    end)
  end
end
