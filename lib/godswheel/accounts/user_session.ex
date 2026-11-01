defmodule GodsWheel.Accounts.UserSession do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_sessions" do
    field :refresh_token_hash, :string
    field :expires_at, :utc_datetime_usec
    field :absolute_expires_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :user, GodsWheel.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end
end
