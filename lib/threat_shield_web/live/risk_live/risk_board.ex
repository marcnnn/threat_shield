defmodule ThreatShieldWeb.RiskLive.RiskBoard do
  use ThreatShieldWeb, :live_view

  alias AshThreatShield.ThreatManagement
  alias AshThreatShield.ThreatManagement.{MitigationStatus, Risk, RiskStatus}
  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.Organisation

  import ThreatShield.Analytics.RiskAnalytics, only: [max_cost: 1, max_frequency: 1]
  import ThreatShieldWeb.Helpers
  use Gettext, backend: ThreatShieldWeb.Gettext
  import ThreatShieldWeb.Icons
  import ThreatShieldWeb.InfoVis
  import ThreatShieldWeb.Labels, only: [risk_status_label: 1, mitigation_status_label: 1]

  @moduledoc """
  See an overview of all risks in the organisation.
  """

  @impl true
  def render(assigns) do
    ~H"""
    <section class="w-full bg-white py-4 shadow-primary-200 shadow-xs">
      <div class="ts-container">
        <.header>
          <.h1>{dgettext("risks", "Risk board")}</.h1>
          <.h3>
            <span class="text-gray-700 inline-block">
              <Icons.organisation_icon class="w-5 h-5" />
            </span>
            {@organisation.name}
          </.h3>
        </.header>
      </div>
    </section>

    <section class="mx-2 lg:mx-auto lg:px-4 mt-4 flex flex-wrap gap-4 justify-center ">
      <div class="none md:block px-6 py-6 bg-white rounded-lg shadow-sm">
        <.risk_quadrants risk_model={@risk_model} size={700} show_labels={true} />
      </div>

      <div class="px-4 pt-4 bg-white rounded-lg shadow-sm" id="risks_by_status" phx-update="ignore">
        <h2 class="px-2 font-semibold flex">
          <.risk_icon class="w-5 h-6 mr-2" />{dgettext("risks", "Risk by status")}
        </h2>
        <div
          class="chart px-2 lg:px-4 w-[16rem] lg:w-88 xl:w-88 "
          data-chart-type="doughnut"
          data-data-point-label={dgettext("risk-board", "Number of risks")}
          data-datasets={@risks_by_status.data |> Jason.encode!()}
          data-dataset-labels={@risks_by_status.labels |> Jason.encode!()}
          data-colors={@risks_by_status.colors |> Jason.encode!()}
        >
          <canvas></canvas>
        </div>
        <h2 class="px-2 font-semibold flex">
          <.mitigation_icon class="w-6 h-6 mr-2" />{dgettext("risks", "Mitigations by status")}
        </h2>
        <div
          class="chart px-2 lg:px-4 py-2 w-[16rem] lg:w-88"
          data-chart-type="doughnut"
          data-data-point-label={dgettext("risk-board", "Number of mitigations")}
          data-datasets={@mitigations_by_status.data |> Jason.encode!()}
          data-dataset-labels={@mitigations_by_status.labels |> Jason.encode!()}
          data-colors={@mitigations_by_status.colors |> Jason.encode!()}
        >
          <canvas></canvas>
        </div>
      </div>

      <div class="px-6 py-6 bg-white rounded-lg shadow-sm">
        <h2 class="px-2 font-semibold">{dgettext("risks", "Risk summary")}</h2>

        <table class="mt-2 w-full">
          <tr :for={item <- @summary}>
            <td class="pl-2">{item.label}</td>
            <td class="pl-8 py-1 text-right">
              {item.value}
            </td>
          </tr>
        </table>
      </div>

      <div class="px-6 py-6 bg-white rounded-lg shadow-sm">
        <h2 class="px-2 font-semibold">{dgettext("risks", "Top 10 risks by severity")}</h2>
        <table class="mt-2 w-full">
          <tr
            :for={risk <- @top_10_severity}
            phx-click="risk-selected"
            phx-value-risk-id={risk.id}
            class="cursor-pointer hover:bg-gray-100"
          >
            <td class="pl-2">{risk.name}</td>
            <td class="pl-8 py-1">
              <.criticality_badge value={risk.severity} title={dgettext("risks", "Severity")} />
            </td>
          </tr>
        </table>
      </div>

      <div class="px-6 py-6 bg-white rounded-lg shadow-sm">
        <h2 class="px-2 font-semibold">{dgettext("risks", "Top 10 risks by costs")}</h2>
        <table class="mt-2 w-full">
          <tr
            :for={risk <- @top_10_costs}
            phx-click="risk-selected"
            phx-value-risk-id={risk.id}
            class="cursor-pointer hover:bg-gray-100"
          >
            <td class="pl-2">{risk.name}</td>
            <td class="px-4 py-2 text-end">
              {risk_cost(risk) |> format_monetary_amount()}
            </td>
          </tr>
        </table>
      </div>
    </section>
    """
  end

  @impl true
  def mount(%{"org_id" => org_id}, _session, socket) do
    user = socket.assigns.current_user

    organisation = Accounts.get_organisation!(org_id, actor: user)
    summary = ThreatManagement.risk_summary!(organisation.id, actor: user)

    # every risk is a point of the chart
    risks =
      ThreatManagement.list_risks!(organisation.id,
        actor: user,
        load: [:estimated_risk_cost, threat: :system]
      )

    socket
    |> assign(:organisation, organisation)
    |> assign(:risks, risks)
    |> assign(:risk_model, risk_model(risks, organisation))
    |> assign(:top_10_severity, summary.top_risks_by_severity)
    |> assign(:top_10_costs, summary.top_risks_by_cost)
    |> assign(:risks_by_status, risks_by_status(summary.risks_by_status))
    |> assign(:mitigations_by_status, mitigations_by_status(summary.mitigations_by_status))
    |> assign(:summary, summary(summary))
    |> ok()
  end

  @impl true
  def handle_event("risk-selected", %{"risk-id" => risk_id}, socket) do
    {risk_id, _} = Integer.parse(risk_id)

    %Risk{} =
      risk =
      socket.assigns.risks
      |> Enum.find(&(&1.id == risk_id))

    socket
    |> push_navigate(to: link_to(risk, socket.assigns.organisation))
    |> noreply()
  end

  # internal

  defp risks_by_status(counts) do
    states = RiskStatus.values()

    %{
      labels: Enum.map(states, &risk_status_label/1),
      data: Enum.map(states, &Map.get(counts, &1, 0)),
      colors: Enum.map(states, &risk_status_color/1)
    }
  end

  defp risk_status_color(:identified), do: "#E23D47"
  defp risk_status_color(:assessed), do: "#E89E2E"
  defp risk_status_color(:mitigated), do: "#59CE56"
  defp risk_status_color(:accepted), do: "#3664B7"

  defp mitigations_by_status(counts) do
    states = MitigationStatus.values()

    %{
      labels: Enum.map(states, &mitigation_status_label/1),
      data: Enum.map(states, &Map.get(counts, &1, 0)),
      colors: Enum.map(states, &mitigation_status_color/1)
    }
  end

  defp mitigation_status_color(:open), do: "#E89E2E"
  defp mitigation_status_color(:in_progress), do: "#CCCC10"
  defp mitigation_status_color(:implemented), do: "#59CE56"
  defp mitigation_status_color(:verified), do: "#47A545"
  defp mitigation_status_color(:failed), do: "#B53139"
  defp mitigation_status_color(:deferred), do: "#6997EA"
  defp mitigation_status_color(:obsolete), do: "#6997EA"

  defp summary(summary) do
    [
      %{label: dgettext("common", "Number of threats"), value: summary.threat_count},
      %{label: dgettext("common", "Number of risks"), value: summary.risk_count},
      %{label: dgettext("common", "Number of mitigations"), value: summary.mitigation_count},
      %{
        label: dgettext("common", "Total risk costs"),
        value: format_monetary_amount(summary.total_risk_cost)
      },
      %{
        label: dgettext("common", "Unmitigated risk costs"),
        value: format_monetary_amount(summary.unmitigated_risk_cost)
      },
      %{
        label: dgettext("common", "Mitigated risk costs"),
        value: format_monetary_amount(summary.mitigated_risk_cost)
      }
    ]
  end

  defp risk_model([], _organisation), do: []

  defp risk_model(risks, %Organisation{} = organisation) when is_list(risks) do
    max_cost = max_cost(risks)

    max_frequency = max_frequency(risks)

    risks
    |> Enum.sort_by(&Risk.severity/1)
    |> Enum.map(fn risk ->
      %{
        id: risk.id,
        name: risk.name,
        cost: normalized_risk_cost(risk, max_cost),
        frequency: normalized_risk_frequency(risk, max_frequency),
        severity: normalized_risk_severity(risk),
        color: color_code_for_criticality(risk.severity, 0.7),
        cost_label: format_monetary_amount(risk_cost(risk)),
        frequency_label: format_number(risk.probability),
        severity_label: format_number(risk.severity),
        link: link_to(risk, organisation)
      }
    end)
  end

  defp risk_cost(%{estimated_risk_cost: cost}), do: cost

  defp normalized_risk_cost(%Risk{} = risk, max_cost) do
    case risk.estimated_risk_cost do
      nil -> 0.05
      cost -> 0.1 + cost / max_cost
    end
  end

  defp normalized_risk_frequency(%Risk{} = risk, max_frequency) do
    case risk.probability do
      nil -> 0.015
      frequency -> 0.02 + frequency / max_frequency * 0.9
    end
  end

  defp normalized_risk_severity(%Risk{} = risk, max_severity \\ 5.0) do
    case risk.severity do
      nil -> 0.015
      severity -> severity / max_severity
    end
  end
end
