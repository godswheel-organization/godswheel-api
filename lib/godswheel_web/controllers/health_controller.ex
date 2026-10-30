defmodule GodsWheelWeb.HealthController do
  use GodsWheelWeb, :controller

  def show(conn, _params) do
    json(conn, %{data: %{status: "ok"}})
  end
end
