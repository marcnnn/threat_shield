defmodule ThreatShield.Accounts.Helpers do
  @moduledoc """
  Helper functions that bridge the old Accounts context API with AshAuthentication.
  These functions are used by LiveViews and controllers during the migration period.
  """

  alias ThreatShield.Accounts.{User, UserNotifier}

  def get_user_by_email(email) when is_binary(email) do
    case Ash.read_one(
           Ash.Query.for_read(User, :get_by_email, %{email: email}, authorize?: false),
           authorize?: false
         ) do
      {:ok, user} -> user
      _ -> nil
    end
  end

  def get_user_by_email_and_password(email, password) when is_binary(password) do
    user = get_user_by_email(to_string(email))

    if user && user.hashed_password && Bcrypt.verify_pass(password, user.hashed_password) do
      user
    else
      Bcrypt.no_user_verify()
      nil
    end
  end

  def get_user!(id) do
    Ash.get!(User, id, authorize?: false)
  end

  def register_user(attrs) do
    User
    |> AshAuthentication.Info.strategy!(:password)
    |> AshAuthentication.Strategy.action(:register, attrs)
  end

  @user_types %{email: :string, password: :string, first_name: :string, last_name: :string}

  def change_user_registration(%User{} = user, attrs \\ %{}) do
    {user, @user_types}
    |> Ecto.Changeset.cast(attrs, [:email, :password])
    |> Ecto.Changeset.validate_required([:email])
    |> Ecto.Changeset.validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> Ecto.Changeset.validate_length(:email, max: 160)
  end

  def change_user_email(user, attrs \\ %{}) do
    {user, @user_types}
    |> Ecto.Changeset.cast(attrs, [:email])
    |> Ecto.Changeset.validate_required([:email])
    |> Ecto.Changeset.validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> Ecto.Changeset.validate_length(:email, max: 160)
  end

  def apply_user_email(user, password, attrs) do
    if user.hashed_password && Bcrypt.verify_pass(password, user.hashed_password) do
      {user, @user_types}
      |> Ecto.Changeset.cast(attrs, [:email])
      |> Ecto.Changeset.validate_required([:email])
      |> Ecto.Changeset.apply_action(:update)
    else
      changeset =
        {user, @user_types}
        |> Ecto.Changeset.cast(attrs, [:email])

      {:error, Ecto.Changeset.add_error(changeset, :current_password, "is not valid")}
    end
  end

  def update_user_email(_user, _token) do
    # Simplified for Ash migration - token-based email updates
    # will be handled by AshAuthentication in a future iteration
    :error
  end

  def deliver_user_update_email_instructions(%User{} = user, _current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(token))
  end

  def change_user_password(user, attrs \\ %{}) do
    {user, @user_types}
    |> Ecto.Changeset.cast(attrs, [:password])
    |> Ecto.Changeset.validate_confirmation(:password, message: "does not match password")
    |> Ecto.Changeset.validate_length(:password, min: 12, max: 72)
  end

  def update_user_password(user, password, attrs) do
    if Bcrypt.verify_pass(password, user.hashed_password) do
      new_password = attrs["password"] || attrs[:password]

      if new_password do
        user
        |> Ash.Changeset.for_update(
          :change_password,
          %{
            current_password: password,
            password: new_password,
            password_confirmation:
              attrs["password_confirmation"] || attrs[:password_confirmation] || new_password
          },
          authorize?: false
        )
        |> Ash.update()
      else
        {:error, :missing_password}
      end
    else
      changeset =
        {user, @user_types}
        |> Ecto.Changeset.cast(attrs, [])

      {:error, Ecto.Changeset.add_error(changeset, :current_password, "is not valid")}
    end
  end

  @session_validity_in_days 60

  def generate_user_session_token(user) do
    Phoenix.Token.sign(ThreatShieldWeb.Endpoint, "user session", user.id)
  end

  def get_user_by_session_token(token) when is_binary(token) do
    max_age = @session_validity_in_days * 86_400

    case Phoenix.Token.verify(ThreatShieldWeb.Endpoint, "user session", token, max_age: max_age) do
      {:ok, user_id} ->
        user = Ash.get!(User, user_id, authorize?: false)

        case Ash.load(user, :organisations, authorize?: false) do
          {:ok, loaded_user} -> loaded_user
          _ -> user
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  def get_user_by_session_token(_), do: nil

  def delete_user_session_token(_token) do
    :ok
  end

  def deliver_user_confirmation_instructions(%User{confirmed_at: confirmed_at}, _url_fun)
      when not is_nil(confirmed_at) do
    {:error, :already_confirmed}
  end

  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(token))
  end

  def confirm_user(_token) do
    # Simplified - AshAuthentication handles confirmation via its own flow
    :error
  end

  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(token))
  end

  def get_user_by_reset_password_token(_token) do
    # Simplified - AshAuthentication handles reset tokens via its own flow
    nil
  end

  def reset_user_password(user, attrs) do
    password = attrs["password"] || attrs[:password]

    if password do
      hashed = Bcrypt.hash_pwd_salt(password)

      user
      |> Ecto.Changeset.change(%{hashed_password: hashed})
      |> ThreatShield.Repo.update()
    else
      {:error, :missing_password}
    end
  end
end
