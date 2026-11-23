defmodule GodsWheelWeb.LegalController do
  use GodsWheelWeb, :controller

  alias GodsWheelWeb.Response

  @documents %{
    terms: {"Terms & Agreement", "legal/terms.md"},
    privacy: {"Privacy Policy", "legal/privacy.md"}
  }

  def terms(conn, _params), do: send_document(conn, :terms)
  def privacy(conn, _params), do: send_document(conn, :privacy)

  defp send_document(conn, document) do
    {title, path} = Map.fetch!(@documents, document)
    file_path = Path.join(:code.priv_dir(:godswheel), path)

    case File.read(file_path) do
      {:ok, content} ->
        Response.send_success(conn, :ok, %{
          title: title,
          content: content,
          content_type: "text/markdown"
        })

      {:error, _reason} ->
        Response.send_error(
          conn,
          :internal_server_error,
          "document_unavailable",
          "The requested document is currently unavailable."
        )
    end
  end
end
