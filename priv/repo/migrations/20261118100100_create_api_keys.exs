defmodule ThreatShield.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :api_key_hash, :binary, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:api_keys, [:api_key_hash], name: "api_keys_unique_api_key_index")
    create index(:api_keys, [:user_id])
  end
end
