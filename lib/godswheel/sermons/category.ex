defmodule GodsWheel.Sermons.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "categories" do
    field :name, :string
    field :slug, :string
    field :description, :string

    many_to_many :sermons, GodsWheel.Sermons.Sermon,
      join_through: "sermon_categories",
      on_replace: :delete

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :description])
    |> update_change(:name, &String.trim/1)
    |> update_change(:slug, &(&1 |> String.trim() |> String.downcase()))
    |> validate_required([:name, :slug])
    |> validate_length(:name, max: 120)
    |> validate_length(:slug, max: 140)
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end
end
