defmodule AshThreatShield.DynamicAttribute do
  @moduledoc """
  A property of an organisation or a system, stored in its map `attributes`: a name,
  a description for the user and the AI assistant, and optionally sample values.
  Without sample values, `get_suggestions/1` asks the AI assistant for typical values
  and caches them; the cache is started by the application of the library.
  """
  use GenServer

  @table :attribute_suggestions

  alias AshThreatShield.AI

  @enforce_keys [:name, :description]
  defstruct [:name, :description, :sample_values]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          sample_values: [String.t()] | nil
        }

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_suggestions(%__MODULE__{sample_values: nil} = attribute) do
    case :ets.lookup(@table, attribute) do
      [{^attribute, suggestions}] ->
        suggestions

      [] ->
        case AI.suggest_values(attribute) do
          suggestions when is_list(suggestions) ->
            :ets.insert(@table, {attribute, suggestions})
            suggestions

          # not cached, so that the next form asks again
          {:error, _reason} ->
            []
        end
    end
  end

  def get_suggestions(%__MODULE__{sample_values: handcoded_values}), do: handcoded_values

  @max_value_length 500

  @doc """
  The error message for an attribute map with an invalid value.
  """
  def invalid_values_message, do: "must be texts of at most #{@max_value_length} characters"

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
