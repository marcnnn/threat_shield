defmodule ThreatShield.Members do
  @moduledoc """
  Compatibility functions for the registration flow (`UserRegistrationLive`), which
  joins an organisation with the token of an invite link. New code calls
  `ThreatShield.Accounts.get_invite_by_token/2` and
  `ThreatShield.Accounts.join_with_token/2` directly.
  """

  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.Errors.InviteError
  alias ThreatShield.Accounts.User

  @doc """
  Returns the open invite of the token with its organisation, or nil. The token is
  the secret of the invite link, so no actor is needed.
  """
  def get_invite_by_token(token) do
    case Accounts.get_invite_by_token(token, load: [:organisation_name]) do
      {:ok, invite} -> invite
      {:error, error} -> raise error
    end
  end

  @doc """
  Makes the user a viewer of the organisation of the invite link.
  """
  def join_with_token(%User{} = user, token) do
    case Accounts.join_with_token(token, actor: user) do
      {:ok, membership} -> {:ok, membership}
      {:error, error} -> {:error, InviteError.reason(error)}
    end
  end
end
