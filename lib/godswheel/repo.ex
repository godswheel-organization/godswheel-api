defmodule GodsWheel.Repo do
  use Ecto.Repo,
    otp_app: :godswheel,
    adapter: Ecto.Adapters.Postgres
end
