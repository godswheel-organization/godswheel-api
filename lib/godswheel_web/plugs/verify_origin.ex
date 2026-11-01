defmodule GodsWheelWeb.Plugs.VerifyOrigin do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    allowed_origin = Application.get_env(:godswheel, :frontend_origin)
    request_origin = get_req_header(conn, "origin") |> List.first()

    if is_binary(allowed_origin) and request_origin == allowed_origin do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(:forbidden, Jason.encode!(%{error: %{code: "invalid_origin", message: "Request origin is not allowed"}}))
      |> halt()
    end
  end
end
