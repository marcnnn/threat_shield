defmodule ThreatShield.Accounts.Errors.InviteError do
  @moduledoc """
  An invite cannot be accepted. The `reason` is one of `:invalid_invite`,
  `:invalid_token`, `:already_member`, and `:email_not_confirmed`.
  """
  use Splode.Error, fields: [:reason], class: :invalid

  def message(%{reason: :invalid_invite}), do: "the invite does not exist or has expired"
  def message(%{reason: :invalid_token}), do: "the token is not valid (anymore)"
  def message(%{reason: :already_member}), do: "the user is already a member of the organisation"

  def message(%{reason: :email_not_confirmed}),
    do: "the email address must be confirmed before an invite can be accepted"

  @doc """
  Returns the reason of the `InviteError` in an error of an Ash action, or the error
  itself if it has none.
  """
  def reason(%{errors: errors} = error) when is_list(errors) do
    Enum.find_value(errors, error, fn
      %__MODULE__{reason: reason} -> reason
      _ -> nil
    end)
  end

  def reason(error), do: error
end
