defmodule GodsWheel.Repo.Migrations.CreateScripturesAndSermonScriptures do
  use Ecto.Migration

  def up do
    create table(:scriptures, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :book, :string, null: false
      add :chapter, :integer, null: false
      add :start_verse, :integer, null: false
      add :end_verse, :integer, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:scriptures, :scriptures_chapter_positive, check: "chapter > 0")
    create constraint(:scriptures, :scriptures_start_verse_positive, check: "start_verse > 0")
    create constraint(:scriptures, :scriptures_end_verse_valid, check: "end_verse >= start_verse")

    create unique_index(
             :scriptures,
             [:book, :chapter, :start_verse, :end_verse],
             name: :scriptures_reference_unique_index
           )

    execute "CREATE INDEX scriptures_book_chapter_index ON scriptures (lower(book), chapter)"

    create table(:sermon_scriptures, primary_key: false) do
      add :sermon_id,
          references(:sermons, type: :binary_id, on_delete: :delete_all),
          null: false

      add :scripture_id,
          references(:scriptures, type: :binary_id, on_delete: :restrict),
          null: false
    end

    create unique_index(:sermon_scriptures, [:sermon_id, :scripture_id])
    create index(:sermon_scriptures, [:scripture_id])

    execute """
    WITH parsed AS (
      SELECT
        id AS sermon_id,
        (regexp_match(scripture_reference, '^(.+?) ([0-9]+):([0-9]+)(-([0-9]+))?$'))[1] AS book,
        ((regexp_match(scripture_reference, '^(.+?) ([0-9]+):([0-9]+)(-([0-9]+))?$'))[2])::integer AS chapter,
        ((regexp_match(scripture_reference, '^(.+?) ([0-9]+):([0-9]+)(-([0-9]+))?$'))[3])::integer AS start_verse,
        COALESCE(
          ((regexp_match(scripture_reference, '^(.+?) ([0-9]+):([0-9]+)(-([0-9]+))?$'))[5])::integer,
          ((regexp_match(scripture_reference, '^(.+?) ([0-9]+):([0-9]+)(-([0-9]+))?$'))[3])::integer
        ) AS end_verse
      FROM sermons
      WHERE scripture_reference ~ '^(.+?) ([0-9]+):([0-9]+)(-([0-9]+))?$'
    ), inserted AS (
      INSERT INTO scriptures (id, book, chapter, start_verse, end_verse, inserted_at, updated_at)
      SELECT gen_random_uuid(), book, chapter, start_verse, end_verse, NOW(), NOW()
      FROM parsed
      ON CONFLICT (book, chapter, start_verse, end_verse) DO NOTHING
      RETURNING id
    )
    INSERT INTO sermon_scriptures (sermon_id, scripture_id)
    SELECT parsed.sermon_id, scriptures.id
    FROM parsed
    JOIN scriptures
      ON lower(scriptures.book) = lower(parsed.book)
     AND scriptures.chapter = parsed.chapter
     AND scriptures.start_verse = parsed.start_verse
     AND scriptures.end_verse = parsed.end_verse
    ON CONFLICT (sermon_id, scripture_id) DO NOTHING
    """
  end

  def down do
    drop table(:sermon_scriptures)
    drop table(:scriptures)
  end
end
