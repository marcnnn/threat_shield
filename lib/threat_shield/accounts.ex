defmodule ThreatShield.Accounts do
  @moduledoc """
  Users, organisations, memberships and invites. The functions defined here are the
  public API: call them with the acting user as `actor:`, the policies of the
  resources decide what the actor may do.
  """
  use Ash.Domain,
    otp_app: :threat_shield,
    extensions: [AshAi]

  # The tools of chat agents over MCP (see docs/specs/mcp.md). Members, invites and
  # API keys are managed only in the web application.
  tools do
    tool :list_organisations, ThreatShield.Accounts.Organisation, :read do
      description "Lists the organisations of which the user is a member, with the " <>
                    "numbers of their threats, risks and mitigations. The ids are the " <>
                    "organisation_id of the other tools."

      load [:threat_count, :risk_count, :mitigation_count]
    end
  end

  resources do
    resource ThreatShield.Accounts.User do
      define :get_user, action: :read, get_by: [:id]
      define :get_user_by_email, action: :get_by_email, args: [:email], not_found_error?: false

      define :register_user, action: :register_with_password
      define :sign_in_user, action: :sign_in_with_password, args: [:email, :password]
      define :sign_in_with_api_key, action: :sign_in_with_api_key, args: [:api_key]

      define :request_confirmation, action: :request_confirmation, args: [:email]
      define :confirm_user, action: :confirm_with_token, args: [:confirm]

      define :request_password_reset,
        action: :request_password_reset_with_password,
        args: [:email]

      define :get_user_by_reset_token,
        action: :get_by_reset_token,
        args: [:reset_token],
        not_found_error?: false

      define :reset_user_password, action: :password_reset_with_password

      define :change_user_password, action: :change_password
      define :change_user_email, action: :change_email, args: [:email, :current_password]
      define :confirm_user_email_change, action: :confirm_email_change, args: [:confirm]
    end

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

    resource ThreatShield.Accounts.ApiKey do
      define :list_api_keys, action: :read
      define :create_api_key, action: :create, args: [:expires_at]
      define :revoke_api_key, action: :destroy, get_by: [:id]
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
