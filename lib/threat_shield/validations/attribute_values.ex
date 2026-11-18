defmodule ThreatShield.Validations.AttributeValues do
  @moduledoc """
  Validates a map of dynamic attributes (see `ThreatShield.DynamicAttribute`): every
  value must be a short text.

      validate {ThreatShield.Validations.AttributeValues, attribute: :attributes}
  """
  use Ash.Resource.Validation

  alias ThreatShield.DynamicAttribute

  @impl true
  def init(opts) do
    if is_atom(opts[:attribute]) and not is_nil(opts[:attribute]) do
      {:ok, opts}
    else
      {:error, "attribute must be an atom"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    field = opts[:attribute]

    case Ash.Changeset.get_attribute(changeset, field) do
      nil ->
        :ok

      attributes ->
        if DynamicAttribute.valid_values?(attributes) do
          :ok
        else
          {:error, field: field, message: DynamicAttribute.invalid_values_message()}
        end
    end
  end
end
