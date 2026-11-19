Code.require_file("../../credo_checks/test_setup.exs", __DIR__)

defmodule CredoChecks.AuthorizeFalseNeedsReasonTest do
  use Credo.Test.Case

  alias CredoChecks.AuthorizeFalseNeedsReason

  test "accepts a comment on the same line or the line above" do
    """
    defmodule Sample do
      def a(query), do: Ash.read(query, authorize?: false) # system operation

      def b(query) do
        query
        # a lookup inside a policy check
        |> Ash.exists?(authorize?: false)
      end

      def c(query) do
        Ash.read(query, actor: nil)
      end
    end
    """
    |> to_source_file()
    |> run_check(AuthorizeFalseNeedsReason)
    |> refute_issues()
  end

  test "reports authorize?: false without a comment" do
    """
    defmodule Sample do
      # reads the invites
      def a(query) do
        query
        |> Ash.read(authorize?: false)
      end

      def b(changeset), do: Ash.create(changeset, authorize?:   false)
    end
    """
    |> to_source_file()
    |> run_check(AuthorizeFalseNeedsReason)
    |> assert_issues(fn issues ->
      assert issues |> Enum.map(& &1.line_no) |> Enum.sort() == [5, 8]
    end)
  end

  test "ignores strings, sigils and comments" do
    ~S'''
    defmodule Sample do
      @doc """
      Never call it with authorize?: false.
      """
      def a, do: "authorize?: false"
      def b, do: ~s(authorize?: false)
      # authorize?: false is not allowed here
    end
    '''
    |> to_source_file()
    |> run_check(AuthorizeFalseNeedsReason)
    |> refute_issues()
  end

  test "a comment two lines above does not count" do
    """
    defmodule Sample do
      # system operation
      def a(query) do
        Ash.read(query, authorize?: false)
      end
    end
    """
    |> to_source_file()
    |> run_check(AuthorizeFalseNeedsReason)
    |> assert_issue(fn issue -> assert issue.line_no == 4 end)
  end
end
