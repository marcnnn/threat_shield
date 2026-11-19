defmodule ThreatShield.Accounts.Rights do
  @moduledoc """
  The rights of the roles in an organisation. This map is the single source of truth:
  the Ash policies authorize with it (the checks of the threat model library ask
  `ThreatShield.Accounts.Authorization`), and the templates use `may?/2` to show only
  the actions that the policies allow.
  """

  alias ThreatShield.Accounts.Membership

  @rights %{
    view_organisation: [:owner, :editor, :viewer],
    edit_organisation: [:owner, :editor],
    delete_organisation: [:owner],
    invite_new_members: [:owner],
    delete_member: [:owner],
    edit_membership: [:owner],
    create_system: [:owner, :editor],
    edit_system: [:owner, :editor],
    delete_system: [:owner, :editor],
    create_asset: [:owner, :editor],
    edit_asset: [:owner, :editor],
    delete_asset: [:owner, :editor],
    create_threat: [:owner, :editor],
    edit_threat: [:owner, :editor],
    delete_threat: [:owner, :editor],
    create_risk: [:owner, :editor],
    edit_risk: [:owner, :editor],
    delete_risk: [:owner, :editor],
    create_mitigation: [:owner, :editor],
    edit_mitigation: [:owner, :editor],
    delete_mitigation: [:owner, :editor]
  }

  @doc """
  Returns the roles that have the right. Raises for an unknown right, so that a typo
  in a policy does not silently deny everything.
  """
  def roles(right) when is_map_key(@rights, right), do: Map.fetch!(@rights, right)
  def roles(right), do: raise(ArgumentError, "unknown right #{inspect(right)}")

  @doc """
  Returns all rights.
  """
  def rights, do: Map.keys(@rights)

  @doc """
  Checks a right for a membership, or for the membership of a scope.
  Without a membership, nothing is allowed.
  """
  def may?(%Membership{role: role}, right), do: role in roles(right)
  def may?(%{membership: membership}, right), do: may?(membership, right)
  def may?(nil, _right), do: false
end
