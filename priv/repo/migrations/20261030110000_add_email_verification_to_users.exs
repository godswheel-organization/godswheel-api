defmodule GodsWheel.Repo.Migrations.AddEmailVerificationToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :email_verified_at, :utc_datetime_usec
    end

    create table(:email_verification_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id,
          references(:users, type: :binary_id, on_delete: :delete_all),
          null: false

      add :token_hash, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :used_at, :utc_datetime_usec

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create unique_index(:email_verification_tokens, [:token_hash])
    create index(:email_verification_tokens, [:user_id])
  end
end
