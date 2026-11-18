defmodule ThreatShield.Repo.Migrations.CreateUserTokens do
  use Ecto.Migration

  def change do
    create table(:user_tokens, primary_key: false) do
      add :jti, :string, null: false, primary_key: true
      add :subject, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :purpose, :string, null: false
      add :extra_data, :map
      add :created_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create unique_index(:user_tokens, [:jti])
  end
end
