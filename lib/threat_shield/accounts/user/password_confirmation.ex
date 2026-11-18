defmodule ThreatShield.Accounts.User.Validations.PasswordConfirmation do
  @moduledoc """
  Validates that the argument `:password_confirmation` equals the argument
  `:password`.

  Unlike the builtin `confirm/2`, it compares with the password as given, also when
  the password itself is invalid, for example too short. A form then shows both
  errors at once.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    password = Ash.Changeset.get_argument(changeset, :password) || given(changeset, :password)
    confirmation = Ash.Changeset.get_argument(changeset, :password_confirmation)

    if password == confirmation do
      :ok
    else
      {:error, field: :password_confirmation, message: "does not match password"}
    end
  end

  defp given(changeset, name) do
    Map.get(changeset.params, to_string(name)) || Map.get(changeset.params, name)
  end
end
