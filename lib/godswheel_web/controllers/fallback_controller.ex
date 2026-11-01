defmodule GodsWheelWeb.FallbackController do
  use GodsWheelWeb, :controller

  alias GodsWheelWeb.Response

  def call(conn, {:error, :invalid_credentials}) do
    Response.send_error(conn, :unauthorized, "invalid_credentials", "Invalid credentials.")
  end
end
