defmodule GodsWheel.Sermons.Speaker do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "speakers" do
    field :name, :string
    field :bio, :string
    field :image_url, :string

    has_many :sermons, GodsWheel.Sermons.Sermon

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(speaker, attrs) do
    speaker
    |> cast(attrs, [:name, :bio, :image_url])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: 160)
  end
end
