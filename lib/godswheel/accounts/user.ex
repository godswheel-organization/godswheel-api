defmodule GodsWheel.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :full_name, :string
    field :email, :string
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :email_verified_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:full_name, :email, :username, :password])
    |> update_change(:full_name, &String.trim/1)
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> update_change(:username, &(&1 |> String.trim() |> String.downcase()))
    |> validate_required([:full_name, :email, :username, :password])
    |> validate_length(:full_name, min: 2, max: 120)
    |> validate_length(:email, max: 254)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-z0-9_]+$/,
      message: "may contain only lowercase letters, numbers, and underscores"
    )
    |> validate_length(:password, min: 8, max: 72)
    |> validate_password_byte_length()
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_password_hash()
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_password_byte_length()
    |> put_password_hash()
  end

  defp validate_password_byte_length(changeset) do
    validate_change(changeset, :password, fn :password, password ->
      if byte_size(password) <= 72 do
        []
      else
        [password: "must be at most 72 bytes"]
      end
    end)
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end
end
