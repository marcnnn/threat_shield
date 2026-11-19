defmodule ThreatShieldWeb.ExportController do
  use ThreatShieldWeb, :controller

  alias AshThreatShield.ThreatManagement
  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.Organisation
  alias ThreatShield.Exporters.ExcelExporter

  def export_to_excel(conn, %{"org_id" => org_id} = _params) do
    user = conn.assigns.current_user

    org =
      %Organisation{} =
      Accounts.get_organisation!(org_id,
        actor: user,
        load: [:systems, threats: [:system_name, :asset_name], assets: [:system_name]]
      )

    risks =
      ThreatManagement.list_risks!(org.id,
        actor: user,
        load: [:threat_name, :estimated_risk_cost]
      )

    mitigations = ThreatManagement.list_mitigations!(org.id, actor: user, load: [:risk_name])

    case ExcelExporter.export(org.systems, org.threats, org.assets, risks, mitigations) do
      {:ok, content} ->
        send_download(conn, {:binary, content},
          filename: "ThreatModel_#{org.name}.xlsx",
          content_disposition: "attachment",
          content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )

      {:error, reason} ->
        conn
        |> put_flash(:error, "Error exporting threats: #{inspect(reason)}")
        |> redirect(to: ~p"/organisations/#{org.id}")
    end
  end

  # internal
end
