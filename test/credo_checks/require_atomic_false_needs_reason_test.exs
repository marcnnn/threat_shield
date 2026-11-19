Code.require_file("../../credo_checks/test_setup.exs", __DIR__)

defmodule CredoChecks.RequireAtomicFalseNeedsReasonTest do
  use Credo.Test.Case

  alias CredoChecks.RequireAtomicFalseNeedsReason

  test "accepts an explained require_atomic? false" do
    """
    defmodule Sample do
      use Ash.Resource

      actions do
        update :update do
          # the validation reads the system
          require_atomic? false
        end

        update :other do
          require_atomic? false # the change locks the organisation
        end

        update :atomic do
          require_atomic? true
        end
      end
    end
    """
    |> to_source_file()
    |> run_check(RequireAtomicFalseNeedsReason)
    |> refute_issues()
  end

  test "reports require_atomic? false without a comment, also as an option" do
    """
    defmodule Sample do
      use Ash.Resource

      actions do
        update :update do
          accept [:name]
          require_atomic? false
        end

        update :other, require_atomic?: false
      end
    end
    """
    |> to_source_file()
    |> run_check(RequireAtomicFalseNeedsReason)
    |> assert_issues(fn issues ->
      assert issues |> Enum.map(& &1.line_no) |> Enum.sort() == [7, 10]
    end)
  end
end
