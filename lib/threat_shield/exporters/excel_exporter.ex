defmodule ThreatShield.Exporters.ExcelExporter do
  @moduledoc """
  Exports the threat model of an organisation to Excel. The threats need the
  calculations `:system_name` and `:asset_name`, the assets `:system_name`, the
  risks `:threat_name` and `:estimated_risk_cost`, and the mitigations `:risk_name`.
  """

  alias Elixlsx.Workbook
  alias Elixlsx.Sheet

  def export(systems, threats, assets, risks, mitigations) do
    sheets = [
      sheet_with_systems(systems),
      sheet_with_threats(threats),
      sheet_with_assets(assets),
      sheet_with_risks(risks),
      sheet_with_mitigations(mitigations)
    ]

    %Workbook{sheets: sheets}
    |> Elixlsx.write_to_memory("ThreatModel.xlsx")
    |> case do
      {:ok, {_filename, content}} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end

  def sheet_with_systems(systems) do
    columns = [
      [title: "Name", width: 50, content: & &1.name],
      [title: "Description", width: 200, content: & &1.description]
    ]

    sheet(columns, systems, "Systems")
  end

  def sheet_with_threats(threats) do
    columns = [
      [title: "Name", width: 50, content: & &1.name],
      [title: "System", width: 25, content: & &1.system_name],
      [title: "Asset", width: 25, content: & &1.asset_name],
      [title: "Description", width: 200, content: & &1.description]
    ]

    sheet(columns, threats, "Threats")
  end

  def sheet_with_assets(assets) do
    colums = [
      [title: "Name", width: 50, content: & &1.name],
      [title: "System", width: 25, content: & &1.system_name],
      [title: "Criticality Loss", width: 25, content: & &1.criticality_loss],
      [title: "Criticality Theft", width: 25, content: & &1.criticality_theft],
      [title: "Criticality Publication", width: 25, content: & &1.criticality_publication],
      [title: "Criticality Overall", width: 25, content: & &1.criticality_overall],
      [title: "Description", width: 200, content: & &1.description]
    ]

    sheet(colums, assets, "Assets")
  end

  def sheet_with_risks(risks) do
    colums = [
      [title: "Name", width: 50, content: & &1.name],
      [title: "Threat", width: 25, content: & &1.threat_name],
      [title: "Severity", width: 25, content: & &1.severity],
      [title: "Probability", width: 25, content: & &1.probability],
      [title: "Estimated_cost_per_incidence", width: 25, content: & &1.estimated_cost],
      [title: "Estimated_cost_per_year", width: 25, content: & &1.estimated_risk_cost],
      [title: "Description", width: 200, content: & &1.description]
    ]

    sheet(colums, risks, "Risks")
  end

  def sheet_with_mitigations(mitigations) do
    columns = [
      [title: "Name", width: 50, content: & &1.name],
      [title: "Risk", width: 50, content: & &1.risk_name],
      [title: "Description", width: 200, content: & &1.description]
    ]

    sheet(columns, mitigations, "Mitigations")
  end

  # sheet generators

  def sheet(columns, data, name) do
    header_row =
      columns
      |> Enum.map(fn column -> header(column) end)

    rows =
      data
      |> Enum.map(fn row ->
        Enum.map(columns, fn column -> column[:content].(row) end)
      end)

    col_widths =
      columns |> Enum.with_index(fn el, idx -> {idx + 1, el[:width] || 50} end) |> Enum.into(%{})

    %Sheet{
      name: name,
      rows: [header_row] ++ rows,
      col_widths: col_widths
    }
  end

  # utilities

  defp header(column) when is_list(column) do
    title = column[:title] || "No title"
    witdh = column[:font_size] || 12
    header(title, witdh)
  end

  defp header(label, size \\ 12) when is_binary(label) do
    [label, bold: true, size: size]
  end
end
