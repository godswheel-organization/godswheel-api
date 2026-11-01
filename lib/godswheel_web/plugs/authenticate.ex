defmodule GodsWheelWeb.Plugs.Authenticate do
  import Plug.Conn

  alias GodsWheel.Accounts
  alias GodsWheelWeb.JWT

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- JWT.verify(token),
         true <- Accounts.active_session?(claims["sid"]),
         %{} = user <- Accounts.get_user(claims["sub"]) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_session_id, claims["sid"])
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(:unauthorized, Jason.encode!(%{error: %{message: "Authentication required"}}))
        |> halt()
    end
  end
end
