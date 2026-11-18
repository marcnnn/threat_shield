defmodule ThreatShield.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ThreatShield.Accounts` domain.
  """

  alias ThreatShield.Accounts

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      accept_toc: true
    })
  end

  @doc """
  Registers a user. The user carries a session token in its metadata, like a user
  that has just signed in.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    # The confirmation instructions of the registration
    receive do
      {:email, %Swoosh.Email{subject: "Confirmation instructions"}} -> :ok
    after
      0 -> :ok
    end

    Ash.Resource.put_metadata(user, :token, session_token(user))
  end

  def confirmed_user_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)

    token = extract_user_token(fn -> Accounts.request_confirmation(user.email) end)

    {:ok, user} = Accounts.confirm_user(token)
    user
  end

  @doc """
  Calls `fun` and returns the token of the link in the email that `fun` sends.
  """
  def extract_user_token(fun) when is_function(fun, 0) do
    flush_emails()
    fun.()
    receive_token()
  end

  # earlier emails, e.g. invites, carry other tokens
  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  defp receive_token do
    receive do
      {:email, %Swoosh.Email{text_body: body}} ->
        case link_token(body) do
          nil -> receive_token()
          token -> token
        end
    after
      0 -> raise "no email with a token was sent"
    end
  end

  @doc """
  Returns the token at the end of the link in the text of an email, or nil.
  """
  def link_token(body) do
    case Regex.run(~r{https?://\S+/([^/\s]+)\s}, body <> "\n") do
      [_, token] -> token
      nil -> nil
    end
  end

  @doc """
  Issues a session token for the user, like a sign in does.
  """
  def session_token(user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    token
  end

  @doc """
  Creates an API key of the user and returns the key itself. It expires after
  `valid_for` seconds (negative for a key that has expired already).
  """
  def api_key_fixture(user, valid_for \\ 3600) do
    {:ok, api_key} = ThreatShield.Accounts.create_api_key(1, actor: user)
    expire_api_key(api_key, valid_for)
    api_key.__metadata__.plaintext_api_key
  end

  @doc """
  Sets the expiry of an API key to `valid_for` seconds from now, also in the past,
  which the create action does not allow.
  """
  def expire_api_key(%ThreatShield.Accounts.ApiKey{id: id}, valid_for) do
    import Ecto.Query, only: [where: 2]

    expires_at = DateTime.add(DateTime.utc_now(), valid_for, :second)

    ThreatShield.Accounts.ApiKey
    |> where(id: ^id)
    |> ThreatShield.Repo.update_all(set: [expires_at: expires_at])
  end
end
