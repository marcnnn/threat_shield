defmodule ThreatShield.ThreatManagement.Validations.SameOrganisation do
  @moduledoc """
  Checks that a referenced record belongs to the organisation of the changed record,
  e.g. that the system of a threat is a system of the threat's organisation.

      validate {SameOrganisation, attribute: :system_id, resource: System}
  """
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def init(opts) do
    if is_atom(opts[:attribute]) and is_atom(opts[:resource]) do
      {:ok, opts}
    else
      {:error, "attribute and resource must be atoms"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    field = opts[:attribute]
    org_id = Ash.Changeset.get_attribute(changeset, :organisation_id)

    case Ash.Changeset.get_attribute(changeset, field) do
      nil ->
        :ok

      id ->
        exists? =
          opts[:resource]
          |> Ash.Query.filter(id == ^id and organisation_id == ^org_id)
          |> Ash.exists?(authorize?: false)

        if exists? do
          :ok
        else
          {:error, field: field, message: "must belong to the same organisation"}
        end
    end
  end
end
