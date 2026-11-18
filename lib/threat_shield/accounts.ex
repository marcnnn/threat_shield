defmodule ThreatShield.Accounts do
  @moduledoc """
  Users, organisations, memberships and invites. The functions defined here are the
  public API: call them with the acting user as `actor:`, the policies of the
  resources decide what the actor may do.
  """
  use Ash.Domain,
    otp_app: :threat_shield

  resources do
    resource ThreatShield.Accounts.User
    resource ThreatShield.Accounts.Token

    resource ThreatShield.Accounts.Organisation do
      define :list_organisations, action: :read
      define :get_organisation, action: :read, get_by: [:id]
      define :create_organisation, action: :create
      define :update_organisation, action: :update
      define :destroy_organisation, action: :destroy, get_by: [:id]
    end

    resource ThreatShield.Accounts.Membership do
      define :get_membership, action: :read, get_by: [:id]
      define :accept_invite, action: :accept_invite, args: [:invite_id]
      define :join_with_token, action: :join_with_token, args: [:token]
      define :update_membership_role, action: :update_role, args: [:role]
      define :destroy_membership, action: :destroy
    end

    resource ThreatShield.Accounts.Invite do
      define :list_received_invites, action: :received
      define :get_invite_by_token, action: :by_token, args: [:token], not_found_error?: false
      define :create_invite, action: :create, args: [:organisation_id]
      define :revoke_invite, action: :destroy, get_by: [:id]
      define :reject_invite, action: :reject, get_by: [:id]
    end
  end

  @doc """
  Deletes the expired invites. This is a system operation of
  `ThreatShield.Periodically` without an actor, so it is not authorized.
  """
  def delete_expired_invites do
    ThreatShield.Accounts.Invite
    |> Ash.Query.for_read(:expired, %{}, authorize?: false)
    |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false, strategy: [:atomic, :stream])
  end
end
