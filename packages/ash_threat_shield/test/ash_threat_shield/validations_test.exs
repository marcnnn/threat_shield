defmodule AshThreatShield.ValidationsTest do
  @moduledoc """
  Validation rules of the resources in the wording of Ash. A host application may
  show them in the wording of its forms.
  """
  use AshThreatShield.DataCase, async: true

  alias AshThreatShield.ThreatManagement.{Asset, Mitigation, Risk, System, Threat}

  defp changeset(resource, attrs) do
    Ash.Changeset.for_create(resource, :create, attrs, authorize?: false)
  end

  test "descriptions and names are limited" do
    for resource <- [Asset, Risk, Mitigation, Threat, System] do
      errors = errors_on(changeset(resource, %{description: String.duplicate("x", 4001)}))

      assert errors.description == ["length must be less than or equal to 4000"],
             inspect(resource)
    end

    assert %{name: ["length must be less than or equal to 60"]} =
             errors_on(changeset(Threat, %{name: String.duplicate("x", 61)}))
  end

  test "risk numbers and criticalities have ranges" do
    errors = errors_on(changeset(Risk, %{severity: 5.5, probability: -1}))
    assert errors.severity == ["must be less than or equal to 5.0"]
    assert errors.probability == ["must be greater than or equal to 0.0"]

    errors = errors_on(changeset(Asset, %{criticality_loss: 6}))
    assert errors.criticality_loss == ["must be less than or equal to 5.0"]
  end

  test "attribute values of a system must be short texts" do
    assert %{attributes: [message]} =
             errors_on(changeset(System, %{attributes: %{"Database" => %{"x" => 1}}}))

    assert message =~ "texts of at most 500 characters"

    valid = changeset(System, %{attributes: %{"Database" => "Postgres"}})
    refute Map.has_key?(errors_on(valid), :attributes)
  end

  test "the description of the organisation uses the properties of the owner resource" do
    text = AshThreatShield.ThreatManagement.Description.organisation(%{name: "ACME"})

    assert text =~ ~s(The name of the organisation is "ACME".)
    assert text =~ ~s("Industry: ", "Examples are finance and health.")
  end
end
