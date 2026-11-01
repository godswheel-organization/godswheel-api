defmodule GodsWheelWeb.HealthController do
  use GodsWheelWeb, :controller

  alias GodsWheelWeb.Response

  def show(conn, _params) do
    json(conn, Response.success(%{status: "ok"}))
  end
end
