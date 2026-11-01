defmodule GodsWheel.Repo.Migrations.CreateUserSessions do
  use Ecto.Migration

  def change do
    create table(:user_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id,
          references(:users, type: :binary_id, on_delete: :delete_all),
          null: false

      add :refresh_token_hash, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :absolute_expires_at, :utc_datetime_usec, null: false
      add :last_used_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_sessions, [:refresh_token_hash])
    create index(:user_sessions, [:user_id])
    create index(:user_sessions, [:expires_at])
  end
end
