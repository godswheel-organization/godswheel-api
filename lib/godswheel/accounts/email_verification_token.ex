defmodule GodsWheel.Accounts.EmailVerificationToken do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "email_verification_tokens" do
    field :token_hash, :string
    field :expires_at, :utc_datetime_usec
    field :used_at, :utc_datetime_usec

    belongs_to :user, GodsWheel.Accounts.User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
