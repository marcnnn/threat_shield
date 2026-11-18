defmodule ThreatShieldWeb.AshErrors do
  @moduledoc """
  Error messages of Ash actions in the wording of the forms.

  Ash words some validation messages differently from Ecto. `normalize/2` gives them
  the Ecto wording, so that the translations in `priv/gettext/errors.pot` apply.
  `ThreatShieldWeb.CoreComponents.translate_error/1` uses it for every form error.
  """

  @doc """
  Returns the field errors of an Ash error or changeset as
  `[{field, {message, vars}}]`, with normalized messages.
  """
  def field_errors(%Ash.Changeset{errors: errors}), do: field_errors(errors)
  def field_errors(%{errors: errors}) when is_list(errors), do: field_errors(errors)

  def field_errors(errors) when is_list(errors) do
    errors
    |> Enum.flat_map(&to_form_errors/1)
    |> Enum.map(fn {field, message, vars} -> {field, normalize(message, vars)} end)
  end

  defp to_form_errors(error) do
    if AshPhoenix.FormData.Error.impl_for(error) do
      error
      |> AshPhoenix.FormData.Error.to_form_error()
      |> List.wrap()
      |> Enum.reject(fn {field, _message, _vars} -> is_nil(field) end)
    else
      []
    end
  end

  @doc """
  Returns the message and the variables of an error in the Ecto wording.
  """
  def normalize("length must be less than or equal to %{max}", vars) do
    {"should be at most %{count} character(s)",
     [count: vars[:max], validation: :length, kind: :max, type: :string]}
  end

  def normalize("length must be greater than or equal to %{min}", vars) do
    {"should be at least %{count} character(s)",
     [count: vars[:min], validation: :length, kind: :min, type: :string]}
  end

  def normalize("is required", _vars), do: {"can't be blank", [validation: :required]}

  def normalize(message, vars), do: {message, Enum.map(vars || [], &whole_number/1)}

  # Float constraints report a limit of 5 as 5.0. Ecto and the translations use 5.
  defp whole_number({key, value}) when is_float(value) and value == trunc(value),
    do: {key, trunc(value)}

  defp whole_number(var), do: var
end
