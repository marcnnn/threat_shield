defmodule ThreatShield.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ThreatShield.Accounts` domain.
  """

  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.Senders.Urls

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
      |> Accounts.register_user(url_context(%{confirm: &"/users/confirm/#{&1}"}))

    # The confirmation instructions of the registration
    receive do
      {:email, %Swoosh.Email{subject: "Confirmation instructions"}} -> :ok
    after
      0 -> :ok
    end

    user
  end

  def confirmed_user_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Accounts.request_confirmation(user.email, context: Urls.context(%{confirm: url}))
      end)

    {:ok, user} = Accounts.confirm_user(token)
    user
  end

  @doc """
  Calls `fun` with a URL builder and returns the token of the link in the email that
  `fun` sends.
  """
  def extract_user_token(fun) do
    fun.(&"[TOKEN]#{&1}[TOKEN]")
    receive_token()
  end

  defp receive_token do
    receive do
      {:email, %Swoosh.Email{text_body: body}} ->
        case String.split(body, "[TOKEN]") do
          [_, token | _] -> token
          _ -> receive_token()
        end
    after
      0 -> raise "no email with a token was sent"
    end
  end

  @doc """
  Returns the URL context for the account emails with the given URL builders.
  """
  def url_context(builders), do: [context: Urls.context(builders)]

  @doc """
  Issues a session token for the user, like a sign in does.
  """
  def session_token(user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    token
  end
end
