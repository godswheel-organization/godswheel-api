defmodule GodsWheelWeb.Plugs.CORS do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    allowed_origin = Application.get_env(:godswheel, :frontend_origin)
    request_origin = get_req_header(conn, "origin") |> List.first()

    conn =
      if is_binary(allowed_origin) and request_origin == allowed_origin do
        conn
        |> put_resp_header("access-control-allow-origin", allowed_origin)
        |> put_resp_header("access-control-allow-credentials", "true")
        |> put_resp_header(
          "access-control-allow-methods",
          "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        )
        |> put_resp_header("access-control-allow-headers", "authorization, content-type, x-requested-with")
        |> put_resp_header("access-control-max-age", "600")
        |> put_resp_header("vary", "Origin")
      else
        conn
      end

    if conn.method == "OPTIONS" do
      conn
      |> send_resp(:no_content, "")
      |> halt()
    else
      conn
    end
  end
end
