defmodule GodsWheel.Sermons.SermonBookmark do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sermon_bookmarks" do
    belongs_to :user, GodsWheel.Accounts.User
    belongs_to :sermon, GodsWheel.Sermons.Sermon

    timestamps(type: :utc_datetime_usec)
  end
end
