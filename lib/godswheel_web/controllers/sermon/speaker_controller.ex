defmodule GodsWheelWeb.Sermon.SpeakerController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Sermons
  alias GodsWheelWeb.Response
  alias GodsWheelWeb.Sermon.SermonJSON

  def index(conn, params) do
    case Sermons.list_speakers(params) do
      {:ok, result} ->
        json(conn, SermonJSON.speakers(result))

      {:error, :invalid_pagination} ->
        Response.send_error(
          conn,
          :unprocessable_entity,
          "invalid_pagination",
          "Invalid pagination parameters."
        )
    end
  end
end
