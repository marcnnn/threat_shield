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
    case :ets.lookup(@table, attribute) do
      [{^attribute, suggestions}] ->
        suggestions

      [] ->
        suggestions = AI.suggest_values(attribute)
        :ets.insert(@table, {attribute, suggestions})
        suggestions
    end
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

  defp valid_value?({_key, value}) when is_binary(value),
    do: String.length(value) <= @max_value_length

  defp valid_value?(_), do: false

  def init(nil) do
    :ets.new(@table, [:set, :public, :named_table])
    {:ok, nil}
  end
end
