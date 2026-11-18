defmodule ThreatShield.Checks.InviteAddressee do
  @moduledoc """
  Authorizes if an invite is addressed to the email address of the actor. Invites are
  matched by address, so the actor must have confirmed it.
  """
  use Ash.Policy.FilterCheck

  @impl true
  def describe(_opts), do: "the invite is addressed to the confirmed email address of the actor"

  @impl true
  def filter(%{confirmed_at: confirmed_at}, _context, _opts) when not is_nil(confirmed_at),
    do: expr(email == ^actor(:email))

  def filter(_actor, _context, _opts), do: expr(false)
end
