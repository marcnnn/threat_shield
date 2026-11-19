Code.require_file("../../credo_checks/test_setup.exs", __DIR__)

defmodule CredoChecks.ActorInWebCallsTest do
  use Credo.Test.Case

  alias CredoChecks.ActorInWebCalls

  @params [
    domains: [MyApp.ThreatManagement, MyApp.Accounts],
    public: [{MyApp.Accounts, :sign_in_user}]
  ]

  defp run(source), do: source |> to_source_file() |> run_check(ActorInWebCalls, @params)

  test "accepts calls with actor:, scope:, or options in a variable" do
    """
    defmodule MyAppWeb.ThreatLive do
      alias MyApp.{Accounts}
      alias MyApp.ThreatManagement

      def mount(%{"id" => id}, _session, socket) do
        threat = ThreatManagement.get_threat!(id, actor: socket.assigns.user, load: [:risks])
        org = Accounts.get_organisation!(threat.organisation_id, scope: socket.assigns.scope)
        {:ok, assign(socket, threat: threat, org: org)}
      end

      def update(threat, attrs, user) do
        threat |> ThreatManagement.update_threat(attrs, actor: user)
      end

      def list(org_id, opts), do: ThreatManagement.list_threats!(org_id, opts)

      def sign_in(email, password), do: Accounts.sign_in_user(email, password)
    end
    """
    |> run()
    |> refute_issues()
  end

  test "reports code interfaces of a domain without actor:" do
    """
    defmodule MyAppWeb.ThreatLive do
      alias MyApp.ThreatManagement, as: TM

      def mount(%{"id" => id}, _session, socket) do
        threat = TM.get_threat!(id, load: [:risks])
        risks = MyApp.ThreatManagement.list_risks!(threat.id)
        {:ok, assign(socket, threat: threat, risks: risks)}
      end
    end
    """
    |> run()
    |> assert_issues(fn issues ->
      assert issues |> Enum.map(& &1.line_no) |> Enum.sort() == [5, 6]
      assert Enum.any?(issues, &(&1.message =~ "TM.get_threat!"))
    end)
  end

  test "an Ash call counts an actor of the query in the same pipeline" do
    """
    defmodule MyAppWeb.ThreatLive do
      require Ash.Query

      def a(user) do
        MyApp.Threat
        |> Ash.Query.for_read(:read, %{}, actor: user)
        |> Ash.read!()
      end

      def b(user), do: Ash.read!(MyApp.Threat, actor: user)

      def c do
        MyApp.Threat
        |> Ash.Query.for_read(:read, %{})
        |> Ash.read!()
      end

      def d(id), do: Ash.get(MyApp.Threat, id)
    end
    """
    |> run()
    |> assert_issues(fn issues ->
      assert issues |> Enum.map(& &1.line_no) |> Enum.sort() == [15, 18]
    end)
  end

  test "reports AshPhoenix form builders without actor:" do
    """
    defmodule MyAppWeb.ThreatForm do
      def a(user), do: AshPhoenix.Form.for_create(MyApp.Threat, :create, actor: user, as: "threat")
      def b, do: AshPhoenix.Form.for_create(MyApp.Threat, :create, as: "threat")
      def c(form, params), do: AshPhoenix.Form.validate(form, params)
    end
    """
    |> run()
    |> assert_issue(fn issue -> assert issue.line_no == 3 end)
  end

  test "ignores other modules" do
    """
    defmodule MyAppWeb.ThreatLive do
      alias MyApp.{Accounts, ThreatManagement}

      def a(socket), do: Phoenix.Component.assign(socket, :a, Enum.map([1], & &1))
      def b(x), do: x.assigns.threat
      def c(f), do: f.(1)
    end
    """
    |> run()
    |> refute_issues()
  end
end
