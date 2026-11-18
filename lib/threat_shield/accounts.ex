defmodule ThreatShield.Accounts do
  use Ash.Domain,
    otp_app: :threat_shield

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

    resource ThreatShield.Accounts.Organisation
    resource ThreatShield.Accounts.Membership
    resource ThreatShield.Accounts.Invite
    resource ThreatShield.Accounts.Token

    resource ThreatShield.Accounts.ApiKey do
      define :create_api_key, action: :create, args: [:expires_at]
    end
  end
end
