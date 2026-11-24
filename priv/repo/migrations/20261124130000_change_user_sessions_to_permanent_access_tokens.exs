defmodule GodsWheel.Repo.Migrations.ChangeUserSessionsToPermanentAccessTokens do
  use Ecto.Migration

  def up do
    execute("DELETE FROM user_sessions")

    alter table(:user_sessions) do
      remove :refresh_token_hash
      remove :expires_at
      remove :absolute_expires_at
      remove :last_used_at
      add :token_hash, :string, null: false
      add :is_valid, :boolean, null: false, default: true
    end

    drop_if_exists index(:user_sessions, [:expires_at])
    create unique_index(:user_sessions, [:token_hash])
    create index(:user_sessions, [:is_valid, :revoked_at])
  end

  def down do
    execute("DELETE FROM user_sessions")

    drop_if_exists index(:user_sessions, [:is_valid, :revoked_at])
    drop_if_exists index(:user_sessions, [:token_hash])

    alter table(:user_sessions) do
      remove :token_hash
      remove :is_valid
      add :refresh_token_hash, :string
      add :expires_at, :utc_datetime_usec
      add :absolute_expires_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec
    end

    create unique_index(:user_sessions, [:refresh_token_hash])
    create index(:user_sessions, [:expires_at])
  end
end
