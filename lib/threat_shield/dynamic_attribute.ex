defmodule ThreatShield.DynamicAttribute do
  use GenServer

  @table :attribute_suggestions

  alias ThreatShield.AI

  @enforce_keys [:name, :description]
  defstruct [:name, :description, :sample_values]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_suggestions(%__MODULE__{sample_values: nil} = attribute) do
    :ets.lookup_element(@table, attribute, 2)
  rescue
    _ ->
      suggestions = AI.suggest_values(attribute)
      :ets.insert(@table, {attribute, suggestions})
      suggestions
  end

  def get_suggestions(%__MODULE__{sample_values: handcoded_values}), do: handcoded_values

  @max_value_length 500

  @doc """
  The error message for an attribute map with an invalid value.
  """
  def invalid_values_message(), do: "must be texts of at most #{@max_value_length} characters"

  @doc """
  Checks an attribute map: every value must be a string of at most
  #{@max_value_length} characters.
  """
  def valid_values?(attributes) when is_map(attributes),
    do: Enum.all?(attributes, &valid_value?/1)

  def valid_values?(_attributes), do: false

  @doc """
  Validates the attribute map of an Ecto changeset, see `valid_values?/1`. The
  forms use it for their live validation.
  """
  def validate_values(%Ecto.Changeset{} = changeset, field) do
    Ecto.Changeset.validate_change(changeset, field, fn _field, attributes ->
      if valid_values?(attributes), do: [], else: [{field, invalid_values_message()}]
    end)
  end

  defp valid_value?({_key, value}) when is_binary(value),
    do: String.length(value) <= @max_value_length

  defp valid_value?(_), do: false

  def init(nil) do
    :ets.new(@table, [:set, :public, :named_table])
    {:ok, nil}
  end
end
