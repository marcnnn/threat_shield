Code.require_file("../../credo_checks/test_setup.exs", __DIR__)

defmodule CredoChecks.NoRepoInWebTest do
  use Credo.Test.Case

  alias CredoChecks.NoRepoInWeb

  defp run(source), do: source |> to_source_file() |> run_check(NoRepoInWeb)

  test "accepts domain calls and a repo mentioned without a call" do
    """
    defmodule MyAppWeb.Router do
      alias MyApp.ThreatManagement

      def dashboard, do: [ecto_repos: [MyApp.Repo]]
      def threats(org_id, user), do: ThreatManagement.list_threats!(org_id, actor: user)
      def report, do: MyAppWeb.Reporter.run()
    end
    """
    |> run()
    |> refute_issues()
  end

  test "reports repo calls and Ecto queries" do
    """
    defmodule MyAppWeb.ThreatLive do
      import Ecto.Query
      alias MyApp.Repo

      def a(id), do: Repo.get!(MyApp.Threat, id)
      def b, do: MyApp.Repo.all(from(t in "threats", select: t.id))
      def c, do: Ecto.Adapters.SQL.query!(MyApp.Repo, "select 1")
    end
    """
    |> run()
    |> assert_issues(fn issues ->
      assert issues |> Enum.map(& &1.line_no) |> Enum.sort() == [2, 5, 6, 7]
    end)
  end
end
