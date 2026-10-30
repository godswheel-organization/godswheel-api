defmodule GodsWheelWeb.FallbackController do
  use GodsWheelWeb, :controller

  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: %{message: "Invalid credentials"}})
  end
end
