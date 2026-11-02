defmodule GodsWheel.Sermons.SermonProgress do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sermon_progress" do
    belongs_to :user, GodsWheel.Accounts.User
    belongs_to :sermon, GodsWheel.Sermons.Sermon
    field :position_seconds, :integer, default: 0

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(progress, attrs) do
    progress
    |> cast(attrs, [:position_seconds])
    |> validate_required([:user_id, :sermon_id, :position_seconds])
    |> validate_number(:position_seconds, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:sermon_id)
    |> unique_constraint([:user_id, :sermon_id])
  end
end
