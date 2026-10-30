defmodule GodsWheelWeb.Plugs.DashboardAuth do
  @moduledoc """
  Protects the production LiveDashboard with HTTP Basic Authentication.

  When no dashboard credentials are configured (development and test),
  requests pass through without authentication.
  """

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case Application.fetch_env(:godswheel, :dashboard_auth) do
      {:ok, credentials} ->
        Plug.BasicAuth.basic_auth(
          conn,
          username: credentials[:username],
          password: credentials[:password]
        )

      :error ->
        conn
    end
  end
end
