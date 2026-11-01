defmodule GodsWheelWeb.AuthJSON do
  alias GodsWheelWeb.Response

  def user(%{user: user}) do
    Response.success(%{
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      email_verified: not is_nil(user.email_verified_at)
    })
  end

  def session(%{user: user, token: token, claims: claims}) do
    Response.success(%{
      user: %{
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        email_verified: not is_nil(user.email_verified_at)
      },
      access_token: token,
      token_type: "Bearer",
      expires_in: GodsWheelWeb.JWT.ttl_seconds(),
      expires_at: DateTime.from_unix!(claims["exp"], :second) |> DateTime.to_iso8601()
    })
  end
end
