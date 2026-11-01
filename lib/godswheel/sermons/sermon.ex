defmodule GodsWheel.Sermons.Sermon do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sermons" do
    field :title, :string
    field :slug, :string
    field :description, :string
    field :audio_url, :string
    field :thumbnail_url, :string
    field :scripture_reference, :string
    field :duration_seconds, :integer
    field :language, :string
    field :published_at, :utc_datetime_usec

    belongs_to :speaker, GodsWheel.Sermons.Speaker

    many_to_many :categories, GodsWheel.Sermons.Category,
      join_through: "sermon_categories",
      on_replace: :delete

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(sermon, attrs) do
    sermon
    |> cast(attrs, [
      :title,
      :slug,
      :description,
      :audio_url,
      :thumbnail_url,
      :scripture_reference,
      :duration_seconds,
      :language,
      :speaker_id,
      :published_at
    ])
    |> update_change(:title, &String.trim/1)
    |> update_change(:slug, &(&1 |> String.trim() |> String.downcase()))
    |> validate_required([:title, :slug, :audio_url, :speaker_id])
    |> validate_length(:title, max: 200)
    |> validate_length(:slug, max: 220)
    |> validate_number(:duration_seconds, greater_than: 0)
    |> foreign_key_constraint(:speaker_id)
    |> unique_constraint(:slug)
  end
end
