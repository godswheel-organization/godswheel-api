defmodule GodsWheel.Repo.Migrations.RemoveUsernameFromUsers do
  use Ecto.Migration

  def change do
    drop_if_exists index(:users, [:username], name: :users_username_index)

    alter table(:users) do
      remove :username
    end
  end
end
