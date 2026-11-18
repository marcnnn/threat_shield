defmodule ThreatShield.Accounts.User.Validations.ResetTokenSubject do
  @moduledoc """
  Validates that the password reset token in the argument `:reset_token` was issued
  for the user that is changed. `AshAuthentication.Strategy.Password.ResetTokenValidation`
  checks only the token itself, so an invalid token is left to it.
  """

  use Ash.Resource.Validation

  alias AshAuthentication.Jwt

  @impl true
  def validate(changeset, _opts, context) do
    with token when is_binary(token) <- Ash.Changeset.get_argument(changeset, :reset_token),
         {:ok, %{"sub" => subject}, _resource} <-
           Jwt.verify(token, changeset.resource, Ash.Context.to_opts(context)),
         false <- subject == AshAuthentication.user_to_subject(changeset.data) do
      {:error, field: :reset_token, message: "is not valid"}
    else
      _ -> :ok
    end
  end
end
