Code.require_file("../../credo_checks/test_setup.exs", __DIR__)

defmodule CredoChecks.NoHostReferencesTest do
  use Credo.Test.Case

  alias CredoChecks.NoHostReferences

  @params [namespaces: [ThreatShield, ThreatShieldWeb], apps: [:threat_shield]]

  defp run(source), do: source |> to_source_file() |> run_check(NoHostReferences, @params)

  test "accepts the library's own modules and configuration" do
    """
    defmodule AshThreatShield.ThreatManagement.Threat do
      alias AshThreatShield.ThreatManagement

      @repo Application.compile_env!(:ash_threat_shield, :repo)

      # ThreatShield.Accounts.Organisation is the owner in ThreatShield
      def doc, do: "see :threat_shield and ThreatShield.Accounts"
      def mod, do: ThreatManagement
      def atom, do: :threat_shield_extra
    end
    """
    |> run()
    |> refute_issues()
  end

  test "reports modules and the application of the host" do
    """
    defmodule AshThreatShield.Owner do
      alias ThreatShield.Accounts.Organisation

      def web, do: ThreatShieldWeb.Endpoint
      def config, do: Application.get_env(:threat_shield, :ai)
      def owner, do: Organisation
    end
    """
    |> run()
    |> assert_issues(fn issues ->
      assert issues |> Enum.map(& &1.line_no) |> Enum.sort() == [2, 4, 5]
    end)
  end
end
