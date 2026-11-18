defmodule ThreatShield.Params do
  @moduledoc """
  Helpers for the parameters that the contexts pass to Ash actions.
  """

  @doc """
  Puts a value into parameters that come either with atom keys (from code) or with
  string keys (from a form). Ash does not accept a mix of both.
  """
  def put(params, key, value) when is_map(params) and is_atom(key) do
    if Enum.any?(Map.keys(params), &is_binary/1) do
      params
      |> Map.delete(key)
      |> Map.put(Atom.to_string(key), value)
    else
      params
      |> Map.delete(Atom.to_string(key))
      |> Map.put(key, value)
    end
  end
end
