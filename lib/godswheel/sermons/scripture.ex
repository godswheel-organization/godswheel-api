defmodule GodsWheel.Sermons.Scripture do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "scriptures" do
    field :book, :string
    field :chapter, :integer
    field :start_verse, :integer
    field :end_verse, :integer

    many_to_many :sermons, GodsWheel.Sermons.Sermon,
      join_through: "sermon_scriptures",
      on_replace: :delete

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(scripture, attrs) do
    scripture
    |> cast(attrs, [:book, :chapter, :start_verse, :end_verse])
    |> update_change(:book, &String.trim/1)
    |> validate_required([:book, :chapter, :start_verse, :end_verse])
    |> validate_length(:book, max: 80)
    |> validate_number(:chapter, greater_than: 0)
    |> validate_number(:start_verse, greater_than: 0)
    |> validate_number(:end_verse, greater_than: 0)
    |> unique_constraint(:start_verse, name: :scriptures_reference_unique_index)
  end
end
