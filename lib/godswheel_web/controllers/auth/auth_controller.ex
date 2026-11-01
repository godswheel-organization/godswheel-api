defmodule GodsWheelWeb.AuthController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Accounts
  alias GodsWheelWeb.{JWT, Response}

  @refresh_cookie "godswheel_refresh"
  @refresh_cookie_path "/api/v1/auth/refresh"

  def signup(conn, %{"user" => attrs}), do: signup(conn, attrs)

  def signup(conn, attrs) when is_map(attrs) do
    case Accounts.register_user(attrs) do
      {:ok, user} ->
        Response.send_success(
          conn,
          :created,
          %{
            message: "Account created. Check your email to verify your account.",
            user: public_user(user)
          }
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        Response.send_error(
          conn,
          :unprocessable_entity,
          "validation_error",
          "The submitted account details are invalid.",
          errors_on(changeset)
        )
    end
  end

  def login(conn, %{"email" => identifier, "password" => password}) do
    case Accounts.authenticate(identifier, password) do
      {:ok, user} ->
        issue_session(conn, user)

      {:error, :email_not_verified} ->
        Response.send_error(
          conn,
          :forbidden,
          "email_not_verified",
          "Verify your email address before logging in."
        )

      {:error, :invalid_credentials} ->
        Response.send_error(
          conn,
          :unauthorized,
          "invalid_credentials",
          "Invalid email or password."
        )
    end
  end

  def login(conn, _params) do
    Response.send_error(
      conn,
      :unprocessable_entity,
      "missing_credentials",
      "identifier (email) and password are required."
    )
  end

  def verify_email(conn, %{"token" => token}) do
    case Accounts.verify_email(token) do
      {:ok, user} ->
        issue_session(conn, user)

      {:error, _reason} ->
        Response.send_error(
          conn,
          :unprocessable_entity,
          "invalid_or_expired_token",
          "The email verification token is invalid or expired."
        )
    end
  end

  def verify_email(conn, _params) do
    Response.send_error(
      conn,
      :unprocessable_entity,
      "missing_token",
      "token is required."
    )
  end

  def refresh(conn, _params) do
    conn = fetch_cookies(conn)

    case conn.cookies[@refresh_cookie] do
      token when is_binary(token) ->
        case Accounts.rotate_user_session(token) do
          {:ok, {user, session, new_refresh_token}} ->
            {:ok, access_token, claims} = JWT.sign(user, session.id)

            conn
            |> put_refresh_cookie(new_refresh_token)
            |> json(
              Response.success(%{
                access_token: access_token,
                token_type: "Bearer",
                expires_in: JWT.ttl_seconds(),
                expires_at:
                  DateTime.from_unix!(claims["exp"], :second) |> DateTime.to_iso8601()
              })
            )

          {:error, _reason} ->
            session_expired(conn)
        end

      _ ->
        session_expired(conn)
    end
  end

  def logout(conn, _params) do
    :ok = Accounts.revoke_user_session(conn.assigns.current_session_id)

    conn
    |> clear_refresh_cookie()
    |> json(Response.success(%{message: "Logged out successfully."}))
  end

  def logout_all(conn, _params) do
    :ok = Accounts.revoke_all_user_sessions(conn.assigns.current_user.id)

    conn
    |> clear_refresh_cookie()
    |> json(Response.success(%{message: "All sessions have been logged out."}))
  end

  def resend_verification(conn, %{"email" => email}) do
    :ok = Accounts.resend_verification_email(email)

    json(
      conn,
      Response.success(%{
        message:
          "If an unverified account exists for that email, a verification email will be sent."
      })
    )
  end

  def resend_verification(conn, _params) do
    Response.send_error(
      conn,
      :unprocessable_entity,
      "missing_email",
      "email is required."
    )
  end

  def me(conn, _params) do
    render(conn, :user, user: conn.assigns.current_user)
  end

  defp issue_session(conn, user) do
    with {:ok, session, refresh_token} <- Accounts.create_user_session(user),
         {:ok, access_token, claims} <- JWT.sign(user, session.id) do
      conn
      |> put_refresh_cookie(refresh_token)
      |> render(:session, user: user, token: access_token, claims: claims)
    else
      {:error, _reason} ->
        Response.send_error(
          conn,
          :internal_server_error,
          "session_creation_failed",
          "Unable to create authenticated session."
        )
    end
  end

  defp session_expired(conn) do
    conn
    |> clear_refresh_cookie()
    |> Response.send_error(
      :unauthorized,
      "session_expired",
      "The session is invalid or expired. Please log in again."
    )
  end

  defp put_refresh_cookie(conn, token) do
    put_resp_cookie(conn, @refresh_cookie, token,
      http_only: true,
      secure: Application.get_env(:godswheel, :refresh_cookie_secure, false),
      same_site: Application.get_env(:godswheel, :refresh_cookie_same_site, "Lax"),
      path: @refresh_cookie_path,
      max_age: Application.get_env(:godswheel, :session_idle_ttl_seconds, 2_592_000)
    )
  end

  defp clear_refresh_cookie(conn) do
    delete_resp_cookie(conn, @refresh_cookie,
      http_only: true,
      secure: Application.get_env(:godswheel, :refresh_cookie_secure, false),
      same_site: Application.get_env(:godswheel, :refresh_cookie_same_site, "Lax"),
      path: @refresh_cookie_path
    )
  end

  defp public_user(user) do
    %{
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      email_verified: not is_nil(user.email_verified_at)
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r/%{(\\w+)}/, message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
