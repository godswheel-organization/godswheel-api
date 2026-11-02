defmodule GodsWheel.Repo.Migrations.CreateUserSermonFeatures do
  use Ecto.Migration

  def change do
    create table(:sermon_progress, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id,
          references(:users, type: :binary_id, on_delete: :delete_all),
          null: false

      add :sermon_id,
          references(:sermons, type: :binary_id, on_delete: :delete_all),
          null: false

      add :position_seconds, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sermon_progress, [:user_id, :sermon_id])
    create index(:sermon_progress, [:sermon_id])

    create table(:sermon_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id,
          references(:users, type: :binary_id, on_delete: :delete_all),
          null: false

      add :sermon_id,
          references(:sermons, type: :binary_id, on_delete: :delete_all),
          null: false

      add :content, :text, null: false, default: ""

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sermon_notes, [:user_id, :sermon_id])
    create index(:sermon_notes, [:sermon_id])

    create table(:sermon_bookmarks, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id,
          references(:users, type: :binary_id, on_delete: :delete_all),
          null: false

      add :sermon_id,
          references(:sermons, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sermon_bookmarks, [:user_id, :sermon_id])
    create index(:sermon_bookmarks, [:sermon_id])
  end
end
