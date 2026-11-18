defmodule ThreatShield.Repo.Migrations.DropUsersTokens do
  use Ecto.Migration

  # The tokens of phx.gen.auth. AshAuthentication keeps its tokens in user_tokens.
  def up do
    drop table(:users_tokens)
  end

  def down do
    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
