defmodule GodsWheel.Repo.Migrations.OptimizeSermonSearchIndexes do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    drop index(:sermons, [:language])
    drop index(:sermons, [:published_at])

    create index(:sermons, [:published_at],
             where: "published_at IS NOT NULL",
             name: :sermons_published_at_index
           )

    execute """
    CREATE INDEX sermons_title_trgm_index
    ON sermons USING GIN (title gin_trgm_ops)
    """

    execute """
    CREATE INDEX sermons_description_trgm_index
    ON sermons USING GIN (description gin_trgm_ops)
    """
  end

  def down do
    drop index(:sermons, [:published_at], name: :sermons_published_at_index)

    execute "DROP INDEX IF EXISTS sermons_title_trgm_index"
    execute "DROP INDEX IF EXISTS sermons_description_trgm_index"

    create index(:sermons, [:published_at])
    create index(:sermons, [:language])
  end
end
