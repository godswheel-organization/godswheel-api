defmodule GodsWheel.Sermons.SermonNote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sermon_notes" do
    belongs_to :user, GodsWheel.Accounts.User
    belongs_to :sermon, GodsWheel.Sermons.Sermon
    field :content, :string, default: ""

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:content])
    |> validate_required([:user_id, :sermon_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:sermon_id)
    |> unique_constraint([:user_id, :sermon_id])
  end
end
