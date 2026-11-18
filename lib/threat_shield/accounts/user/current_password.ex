defmodule ThreatShield.Accounts.User.Validations.CurrentPassword do
  @moduledoc """
  Validates that the argument given as `:argument` is the current password of the
  user. Wraps `AshAuthentication.Strategy.Password.PasswordValidation` and reports a
  wrong password as an error of that argument, so that forms can show it.
  """

  use Ash.Resource.Validation

  alias AshAuthentication.Strategy.Password.PasswordValidation

  @impl true
  def init(opts) do
    if is_atom(opts[:argument]),
      do: {:ok, opts},
      else: {:error, "argument must be the name of the password argument"}
  end

  @impl true
  def validate(changeset, opts, context) do
    case PasswordValidation.validate(
           changeset,
           [strategy_name: :password, password_argument: opts[:argument]],
           context
         ) do
      :ok ->
        :ok

      {:error, _authentication_failed} ->
        {:error, field: opts[:argument], message: "is not valid"}
    end
  end
end
