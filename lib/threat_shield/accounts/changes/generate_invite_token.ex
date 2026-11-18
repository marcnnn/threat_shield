defmodule ThreatShield.Accounts.Changes.GenerateInviteToken do
  @moduledoc """
  Sets a random token for the link of an invite.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    token = :crypto.strong_rand_bytes(128) |> Base.url_encode64(padding: false)
    Ash.Changeset.force_change_attribute(changeset, :token, token)
  end
end
