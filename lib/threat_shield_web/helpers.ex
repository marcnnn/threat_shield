defmodule ThreatShieldWeb.Helpers do
  use Phoenix.VerifiedRoutes,
    endpoint: ThreatShieldWeb.Endpoint,
    router: ThreatShieldWeb.Router

  alias ThreatShield.Accounts.Organisation

  import Phoenix.Component
  alias ThreatShieldWeb.Endpoint

  alias AshThreatShield.ThreatManagement.Asset
  alias AshThreatShield.ThreatManagement.Risk
  alias AshThreatShield.ThreatManagement.System
  alias AshThreatShield.ThreatManagement.Threat

  alias ThreatShield.Scope

  @moduledoc """
  Helpers are functions that can be used in your contexts.
  """

  def add_breadcrumbs(socket, url) do
    relevant_url_parts =
      %{
        "organisations" => :organisations,
        "assets" => :assets,
        "systems" => :systems,
        "threats" => :threats,
        "risks" => :risks,
        "mitigations" => :mitigations,
        "members" => :members
      }

    breadcrumbs =
      url
      |> String.replace_prefix(Endpoint.url(), "")
      |> String.split("/")
      |> Enum.map(fn key -> Map.get(relevant_url_parts, key) end)
      |> Enum.filter(&(!is_nil(&1)))

    assign(socket, :breadcrumbs, [:home | breadcrumbs])
  end

  def generate_token do
    :crypto.strong_rand_bytes(128)
    |> Base.url_encode64(padding: false)
  end

  def get_path_prefix(assigns) do
    case assigns[:system] do
      nil -> "/organisations/#{assigns.organisation.id}"
      system -> "/organisations/#{assigns.organisation.id}/systems/#{system.id}"
    end
  end

  # Time

  def convert_date(date_str) do
    {:ok, result} = Timex.format(date_str, "{0D}.{0M}.{YYYY}")
    result
  end

  def format_datetime(datetime) do
    {:ok, formatted} = Timex.format(datetime, "{YYYY}-{0M}-{0D} - {h24}:{m}:{s}")
    formatted
  end

  # Numbers

  def format_number(nil) do
    "-"
  end

  def format_number(number) do
    integer = number |> to_decimal() |> Decimal.round(0) |> Decimal.to_integer()
    sign = if integer < 0, do: "-", else: ""
    sign <> delimit(Integer.to_string(abs(integer)))
  end

  defp to_decimal(%Decimal{} = number), do: number
  defp to_decimal(number) when is_integer(number), do: Decimal.new(number)
  defp to_decimal(number) when is_float(number), do: Decimal.from_float(number)
  defp to_decimal(number) when is_binary(number), do: Decimal.new(number)

  # inserts a "." between groups of three digits
  defp delimit(digits) do
    digits
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(".", &Enum.join/1)
    |> String.reverse()
  end

  @spec format_monetary_amount(nil | binary() | number() | Decimal.t(), any()) ::
          nonempty_binary()
  def format_monetary_amount(number, currency \\ "EUR")
  def format_monetary_amount(nil, _currency), do: "-"

  def format_monetary_amount(number, currency) do
    "#{format_number(number)} #{currency}"
  end

  # URLs

  def link_to(%Risk{id: risk_id, threat: %Threat{id: threat_id} = threat}, %Organisation{
        id: org_id
      }) do
    case {threat.system_id, threat.asset_id} do
      {nil, nil} ->
        ~p"/organisations/#{org_id}/threats/#{threat_id}/risks/#{risk_id}"

      {system_id, _} ->
        ~p"/organisations/#{org_id}/systems/#{system_id}/threats/#{threat_id}/risks/#{risk_id}"
    end
  end

  def link_to(%Risk{id: risk_id, threat_id: threat_id}, %Organisation{id: org_id}) do
    ~p"/organisations/#{org_id}/threats/#{threat_id}/risks/#{risk_id}"
  end

  def link_to(%Risk{} = risk, %Scope{organisation: org}) do
    link_to(risk, org)
  end

  def link_to(%Threat{id: threat_id, organisation_id: org_id} = threat) do
    case {threat.system_id, threat.asset_id} do
      {nil, nil} ->
        ~p"/organisations/#{org_id}/threats/#{threat_id}"

      {system_id, nil} ->
        ~p"/organisations/#{org_id}/systems/#{system_id}/threats/#{threat_id}"

      {nil, asset_id} ->
        ~p"/organisations/#{org_id}/assets/#{asset_id}/threats/#{threat_id}"

      {system_id, asset_id} ->
        ~p"/organisations/#{org_id}/systems/#{system_id}/assets/#{asset_id}/threats/#{threat_id}"
    end
  end

  def link_to(%Asset{organisation_id: org_id} = asset) do
    case asset.system_id do
      nil -> ~p"/organisations/#{org_id}/assets/#{asset.id}"
      system_id -> ~p"/organisations/#{org_id}/systems/#{system_id}/assets/#{asset.id}"
    end
  end

  def link_to(%System{id: system_id, organisation_id: org_id}) do
    ~p"/organisations/#{org_id}/systems/#{system_id}"
  end

  def link_to(%Organisation{id: org_id}) do
    ~p"/organisations/#{org_id}"
  end

  @doc """
  The options of a select for the system of an entity: "None" and the systems of the
  organisation, which need to be loaded.
  """
  def system_options(%Organisation{systems: systems}) when is_list(systems),
    do: [{"None", nil} | Enum.map(systems, &{&1.name, &1.id})]

  def system_options(_organisation), do: [{"None", nil}]

  @doc """
  The options of a select for the asset of an entity: "None" and the assets of the
  organisation, which need to be loaded.
  """
  def asset_options(%Organisation{assets: assets}) when is_list(assets),
    do: [{"None", nil} | Enum.map(assets, &{&1.name, &1.id})]

  def asset_options(_organisation), do: [{"None", nil}]
end
