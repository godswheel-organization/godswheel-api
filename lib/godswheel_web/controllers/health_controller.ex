defmodule GodsWheelWeb.HealthController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Repo
  alias GodsWheelWeb.Response

  @database_check_timeout_ms 2_000

  def show(conn, _params) do
    case database_health() do
      :ok ->
        Response.send_success(conn, :ok, %{
          status: "ok",
          checks: %{application: "ok", database: "ok"}
        })

      :error ->
        Response.send_error(
          conn,
          :service_unavailable,
          "service_unavailable",
          "A required service is unavailable.",
          %{checks: %{application: "ok", database: "error"}}
        )
    end
  end

  def live(conn, _params) do
    Response.send_success(conn, :ok, %{
      status: "ok",
      checks: %{application: "ok"}
    })
  end

  defp database_health do
    case Repo.query("SELECT 1", [], timeout: @database_check_timeout_ms) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :error
    end
  rescue
    _error -> :error
  catch
    _kind, _reason -> :error
  end
end
