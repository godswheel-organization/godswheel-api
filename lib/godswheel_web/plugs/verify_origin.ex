defmodule GodsWheelWeb.Plugs.VerifyOrigin do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    allowed_origins = Application.get_env(:godswheel, :frontend_origins, [])
    request_origin = get_req_header(conn, "origin") |> List.first()

    if request_origin in allowed_origins do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        :forbidden,
        Jason.encode!(%{
          error: %{
            code: "invalid_origin",
            message: "Request origin is not allowed"
          }
        })
      )
      |> halt()
    end
  end
end
