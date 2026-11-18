defmodule ThreatShieldWeb.AshErrors do
  @moduledoc """
  Turns the errors of an Ash action into field errors of an Ecto changeset, so that
  the forms can show them.

  The forms are still built from Ecto changesets. Until they use `AshPhoenix.Form`,
  this module puts the errors that an Ash action returns into the changeset of the
  form. Messages that Ash words differently from Ecto are given the Ecto wording, so
  that the translations in `priv/gettext/errors.pot` apply.
  """

  @doc """
  Returns the field errors of an Ash error or changeset as
  `[{field, {message, vars}}]`.
  """
  def field_errors(%Ash.Changeset{errors: errors}), do: field_errors(errors)
  def field_errors(%{errors: errors}) when is_list(errors), do: field_errors(errors)

  def field_errors(errors) when is_list(errors) do
    errors
    |> Enum.flat_map(&to_form_errors/1)
    |> Enum.map(fn {field, message, vars} -> {field, normalize(message, vars)} end)
  end

  @doc """
  Replaces the errors of an Ecto changeset with the field errors of an Ash error.
  """
  def add_to_changeset(%Ecto.Changeset{} = changeset, error) do
    error
    |> field_errors()
    |> Enum.reduce(%{changeset | errors: [], valid?: true}, fn {field, {message, vars}},
                                                               changeset ->
      Ecto.Changeset.add_error(changeset, field, message, vars)
    end)
    |> Map.put(:action, changeset.action || :insert)
  end

  @doc """
  For the option `post_process_errors` of `AshPhoenix.Form`: gives an error the
  Ecto wording, like `field_errors/1`.
  """
  def post_process_error(_form, _path, {field, message, vars}) do
    {message, vars} = normalize(message, vars)
    {field, message, vars}
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

  defp normalize("length must be less than or equal to %{max}", vars) do
    {"should be at most %{count} character(s)",
     [count: vars[:max], validation: :length, kind: :max, type: :string]}
  end

  defp normalize("length must be greater than or equal to %{min}", vars) do
    {"should be at least %{count} character(s)",
     [count: vars[:min], validation: :length, kind: :min, type: :string]}
  end

  defp normalize("is required", _vars), do: {"can't be blank", [validation: :required]}

  defp normalize(message, vars), do: {message, Enum.map(vars || [], &whole_number/1)}

  # Float constraints report a limit of 5 as 5.0. Ecto and the translations use 5.
  defp whole_number({key, value}) when is_float(value) and value == trunc(value),
    do: {key, trunc(value)}

  defp whole_number(var), do: var
end
