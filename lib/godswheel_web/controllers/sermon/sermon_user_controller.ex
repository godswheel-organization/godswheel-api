defmodule GodsWheelWeb.Sermon.SermonUserController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Sermons
  alias GodsWheelWeb.Response
  alias GodsWheelWeb.Sermon.SermonJSON

  def progress(conn, %{"id" => sermon_id}) do
    case Sermons.get_sermon_progress(conn.assigns.current_user.id, sermon_id) do
      {:ok, progress} ->
        json(conn, Response.success(progress_data(progress)))

      {:error, :not_found} ->
        sermon_not_found(conn)
    end
  end

  def save_progress(conn, %{"id" => sermon_id} = params) do
    case Sermons.save_sermon_progress(
           conn.assigns.current_user.id,
           sermon_id,
           params["position_seconds"]
         ) do
      {:ok, progress} ->
        json(conn, Response.success(progress_data(progress)))

      {:error, :invalid_position} ->
        Response.send_error(
          conn,
          :unprocessable_entity,
          "invalid_position",
          "position_seconds must be a non-negative integer."
        )

      {:error, :not_found} ->
        sermon_not_found(conn)

      {:error, %Ecto.Changeset{}} ->
        Response.send_error(
          conn,
          :unprocessable_entity,
          "invalid_position",
          "position_seconds must be a non-negative integer."
        )
    end
  end

  def note(conn, %{"id" => sermon_id}) do
    case Sermons.get_sermon_note(conn.assigns.current_user.id, sermon_id) do
      {:ok, note} ->
        json(conn, Response.success(note_data(note)))

      {:error, :not_found} ->
        sermon_not_found(conn)
    end
  end

  def save_note(conn, %{"id" => sermon_id, "content" => content}) when is_binary(content) do
    case Sermons.save_sermon_note(conn.assigns.current_user.id, sermon_id, content) do
      {:ok, note} ->
        json(conn, Response.success(note_data(note)))

      {:error, :not_found} ->
        sermon_not_found(conn)

      {:error, %Ecto.Changeset{}} ->
        Response.send_error(conn, :unprocessable_entity, "invalid_note", "Invalid note content.")
    end
  end

  def save_note(conn, _params) do
    Response.send_error(
      conn,
      :unprocessable_entity,
      "invalid_note",
      "content must be a string."
    )
  end

  def bookmarks(conn, params) do
    case Sermons.list_bookmarked_sermons(conn.assigns.current_user.id, params) do
      {:ok, result} ->
        json(conn, SermonJSON.index(result))

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def create_bookmark(conn, %{"id" => sermon_id}) do
    case Sermons.create_sermon_bookmark(conn.assigns.current_user.id, sermon_id) do
      :ok ->
        Response.send_success(conn, :created, %{message: "Sermon bookmarked."})

      {:error, :not_found} ->
        sermon_not_found(conn)

      {:error, _reason} ->
        Response.send_error(
          conn,
          :unprocessable_entity,
          "bookmark_failed",
          "Could not bookmark sermon."
        )
    end
  end

  def delete_bookmark(conn, %{"id" => sermon_id}) do
    case Sermons.delete_sermon_bookmark(conn.assigns.current_user.id, sermon_id) do
      :ok ->
        Response.send_success(conn, :ok, %{message: "Bookmark removed."})

      {:error, :not_found} ->
        Response.send_error(conn, :not_found, "bookmark_not_found", "Bookmark not found.")
    end
  end

  defp progress_data(nil), do: nil

  defp progress_data(progress) do
    %{
      sermon_id: progress.sermon_id,
      position_seconds: progress.position_seconds,
      position_updated_at: progress.position_updated_at,
      updated_at: progress.updated_at
    }
  end

  defp note_data(nil), do: nil

  defp note_data(note) do
    %{
      sermon_id: note.sermon_id,
      content: note.content,
      inserted_at: note.inserted_at,
      updated_at: note.updated_at
    }
  end

  defp sermon_not_found(conn) do
    Response.send_error(conn, :not_found, "sermon_not_found", "Sermon not found.")
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
