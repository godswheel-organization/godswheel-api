defmodule GodsWheel.Repo.Migrations.CreateSermonCatalogue do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:categories, [:name])
    create unique_index(:categories, [:slug])

    create table(:speakers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :bio, :text
      add :image_url, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:speakers, [:name])

    create table(:sermons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :speaker_id,
          references(:speakers, type: :binary_id, on_delete: :restrict),
          null: false

      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :audio_url, :string, null: false
      add :thumbnail_url, :string
      add :scripture_reference, :string
      add :duration_seconds, :integer
      add :language, :string
      add :published_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sermons, [:slug])
    create index(:sermons, [:speaker_id])
    create index(:sermons, [:published_at])
    create index(:sermons, [:language])

    create table(:sermon_categories, primary_key: false) do
      add :sermon_id,
          references(:sermons, type: :binary_id, on_delete: :delete_all),
          null: false

      add :category_id,
          references(:categories, type: :binary_id, on_delete: :delete_all),
          null: false
    end

    create unique_index(:sermon_categories, [:sermon_id, :category_id])
    create index(:sermon_categories, [:category_id])
  end
end
