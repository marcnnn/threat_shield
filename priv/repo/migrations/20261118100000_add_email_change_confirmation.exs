defmodule ThreatShield.Repo.Migrations.AddEmailChangeConfirmation do
  use Ecto.Migration

  def change do
    # When the last change of the email address was confirmed
    alter table(:users) do
      add :email_change_confirmed_at, :utc_datetime_usec
    end

    # Tokens are looked up by subject (sign out everywhere) and by expiry (clean up)
    create index(:user_tokens, [:subject])
    create index(:user_tokens, [:expires_at])
  end
end
