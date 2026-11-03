defmodule GodsWheel.Repo.Migrations.AddPositionUpdatedAtToSermonProgress do
  use Ecto.Migration

  def change do
    alter table(:sermon_progress) do
      add :position_updated_at,
          :utc_datetime_usec,
          null: false,
          default: fragment("CURRENT_TIMESTAMP")
    end
  end
end
