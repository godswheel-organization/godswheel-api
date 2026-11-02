defmodule GodsWheelWeb.Sermon.SermonController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Sermons
  alias GodsWheel.Storage.Tigris
  alias GodsWheelWeb.Response
  alias GodsWheelWeb.Sermon.SermonJSON

  def index(conn, params) do
    case Sermons.list_sermons(params) do
      {:ok, result} ->
        json(conn, SermonJSON.index(result))

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def show(conn, %{"id" => id}) do
    case Sermons.get_sermon(id) do
      {:ok, sermon} ->
        json(conn, SermonJSON.show(sermon))

      {:error, :not_found} ->
        Response.send_error(conn, :not_found, "sermon_not_found", "Sermon not found.")
    end
  end

  def audio(conn, %{"id" => id}) do
    with {:ok, audio_key} <- Sermons.get_sermon_audio(id),
         {:ok, playback} <- Tigris.playback_url(audio_key) do
      conn
      |> put_resp_header("cache-control", "no-store")
      |> json(Response.success(playback))
    else
      {:error, :not_found} ->
        Response.send_error(conn, :not_found, "sermon_not_found", "Sermon not found.")

      {:error, :audio_not_found} ->
        Response.send_error(conn, :not_found, "audio_not_found", "Audio is not available.")

      {:error, :storage_not_configured} ->
        Response.send_error(
          conn,
          :service_unavailable,
          "audio_storage_unavailable",
          "Audio playback is temporarily unavailable."
        )

      {:error, :invalid_audio_key} ->
        Response.send_error(conn, :not_found, "audio_not_found", "Audio is not available.")
    end
  end

  defp render_error(conn, :invalid_pagination) do
    Response.send_error(
      conn,
      :unprocessable_entity,
      "invalid_pagination",
      "Invalid pagination parameters."
    )
  end

  defp render_error(conn, {:invalid_filter, field}) do
    Response.send_error(
      conn,
      :unprocessable_entity,
      "invalid_filter",
      "Invalid #{field} parameter.",
      %{field: field}
    )
  end
end
