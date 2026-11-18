defmodule ThreatShield.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ThreatShield.Accounts` context.
  """

  alias ThreatShield.Accounts.Helpers, as: Accounts

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    password = attrs[:password] || valid_user_password()

    Enum.into(attrs, %{
      email: unique_user_email(),
      password: password,
      password_confirmation: password
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  def confirmed_user_fixture(attrs \\ %{}) do
    attrs
    |> user_fixture()
    # The confirmation flow of AshAuthentication needs a token; set the time directly.
    |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now())
    |> ThreatShield.Repo.update!()
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
