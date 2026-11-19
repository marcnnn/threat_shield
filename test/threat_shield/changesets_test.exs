defmodule ThreatShield.ChangesetsTest do
  @moduledoc """
  Validation rules of the resources: lengths that match the database columns, number
  ranges, and attribute values. The rules are checked on the changeset of the
  create action.
  """
  use ThreatShield.DataCase, async: true

  alias ThreatShield.Accounts.Organisation
  alias AshThreatShield.ThreatManagement.Asset
  alias AshThreatShield.ThreatManagement.Mitigation
  alias AshThreatShield.ThreatManagement.Risk
  alias AshThreatShield.ThreatManagement.System
  alias AshThreatShield.ThreatManagement.Threat

  # The changeset of the create action, as the contexts build it
  defp changeset(resource, attrs) do
    Ash.Changeset.for_create(resource, :create, attrs, authorize?: false)
  end

  @long_text String.duplicate("x", 4001)
  @long_line String.duplicate("x", 256)

  test "descriptions are limited to the column size" do
    for {schema, extra} <- [
          {Asset, %{}},
          {Risk, %{}},
          {Mitigation, %{}},
          {Threat, %{}},
          {System, %{}}
        ] do
      changeset = changeset(schema, Map.put(extra, :description, @long_text))

      assert %{description: ["should be at most 4000 character(s)"]} = errors_on(changeset),
             "#{inspect(schema)}"
    end
  end

  test "names are limited" do
    assert %{name: ["should be at most 60 character(s)"]} =
             errors_on(changeset(Threat, %{name: String.duplicate("x", 61)}))

    assert %{
             name: ["should be at most 255 character(s)"],
             location: ["should be at most 255 character(s)"]
           } =
             errors_on(changeset(Organisation, %{name: @long_line, location: @long_line}))
  end

  test "mitigation text fields are limited to the column size" do
    changeset =
      changeset(Mitigation, %{
        implementation_notes: @long_line,
        verification_method: @long_line,
        verification_result: @long_line,
        issue_link: @long_line
      })

    errors = errors_on(changeset)

    for field <- [:implementation_notes, :verification_method, :verification_result, :issue_link] do
      assert errors[field] == ["should be at most 255 character(s)"]
    end
  end

  test "the messages of the library validations have the wording of the forms" do
    # "is required" of the library, see ThreatShieldWeb.AshErrors
    assert %{status: ["can't be blank"]} =
             errors_on(changeset(Mitigation, %{name: "n", description: "d", status: nil}))
  end

  test "risk numbers have ranges" do
    changeset =
      changeset(Risk, %{severity: 5.5, probability: -1, estimated_cost: 3_000_000_000})

    errors = errors_on(changeset)
    assert errors.severity == ["must be less than or equal to 5"]
    assert errors.probability == ["must be greater than or equal to 0"]
    assert errors.estimated_cost == ["must be less than or equal to 2147483647"]

    valid = changeset(Risk, %{severity: 5, probability: 0, estimated_cost: 1_000_000})
    refute Map.has_key?(errors_on(valid), :severity)
  end

  test "asset criticality is between 0 and 5" do
    changeset = changeset(Asset, %{criticality_loss: 6, criticality_overall: -0.5})

    errors = errors_on(changeset)
    assert errors.criticality_loss == ["must be less than or equal to 5"]
    assert errors.criticality_overall == ["must be greater than or equal to 0"]
  end

  test "attribute values must be short texts" do
    for schema <- [Organisation, System] do
      assert %{attributes: [message]} =
               errors_on(changeset(schema, %{attributes: %{"Industry" => %{"x" => 1}}}))

      assert message =~ "texts of at most 500 characters"

      assert %{attributes: [_]} =
               errors_on(
                 changeset(schema, %{
                   attributes: %{"Industry" => String.duplicate("x", 501)}
                 })
               )

      valid = changeset(schema, %{attributes: %{"Industry" => "Finance"}})
      refute Map.has_key?(errors_on(valid), :attributes)
    end
  end
end
