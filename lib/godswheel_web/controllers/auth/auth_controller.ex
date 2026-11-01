defmodule GodsWheelWeb.AuthController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Accounts
  alias GodsWheelWeb.JWT

  @refresh_cookie "godswheel_refresh"
  @refresh_cookie_path "/api/v1/auth/refresh"

  action_fallback GodsWheelWeb.FallbackController

  def signup(conn, %{"user" => attrs}), do: signup(conn, attrs)

  def signup(conn, attrs) when is_map(attrs) do
    case Accounts.register_user(attrs) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            message: "Account created. Check your email to verify your account.",
            user: public_user(user)
          }
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors_on(changeset)})
    end
  end

  def login(conn, %{"identifier" => identifier, "password" => password}) do
    case Accounts.authenticate(identifier, password) do
      {:ok, user} ->
        issue_session(conn, user)

      {:error, :email_not_verified} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: %{
            code: "email_not_verified",
            message: "Verify your email address before logging in."
          }
        })

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{message: "Invalid email or password"}})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{message: "identifier (email) and password are required"}})
  end

  def verify_email(conn, %{"token" => token}) do
    case Accounts.verify_email(token) do
      {:ok, user} ->
        issue_session(conn, user)

      {:error, _reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            code: "invalid_or_expired_token",
            message: "The email verification token is invalid or expired."
          }
        })
    end
  end

  def verify_email(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{message: "token is required"}})
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
            |> json(%{
              data: %{
                access_token: access_token,
                token_type: "Bearer",
                expires_in: JWT.ttl_seconds(),
                expires_at: DateTime.from_unix!(claims["exp"], :second) |> DateTime.to_iso8601()
              }
            })

          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{
              error: %{
                code: "session_expired",
                message: "The session is invalid or expired. Please log in again."
              }
            })
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: %{
            code: "session_expired",
            message: "The session is invalid or expired. Please log in again."
          }
        })
    end
  end

  def logout(conn, _params) do
    :ok = Accounts.revoke_user_session(conn.assigns.current_session_id)

    conn
    |> clear_refresh_cookie()
    |> json(%{data: %{message: "Logged out successfully."}})
  end

  def logout_all(conn, _params) do
    :ok = Accounts.revoke_all_user_sessions(conn.assigns.current_user.id)

    conn
    |> clear_refresh_cookie()
    |> json(%{data: %{message: "All sessions have been logged out."}})
  end

  defp issue_session(conn, user) do
    with {:ok, session, refresh_token} <- Accounts.create_user_session(user),
         {:ok, access_token, claims} <- JWT.sign(user, session.id) do
      conn
      |> put_refresh_cookie(refresh_token)
      |> render(:session, user: user, token: access_token, claims: claims)
    else
      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{message: "Unable to create authenticated session."}})
    end
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

  def resend_verification(conn, %{"email" => email}) do
    :ok = Accounts.resend_verification_email(email)

    json(conn, %{
      data: %{
        message: "If an unverified account exists for that email, a verification email will be sent."
      }
    })
  end

  def resend_verification(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{message: "email is required"}})
  end

  def me(conn, _params) do
    render(conn, :user, user: conn.assigns.current_user)
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
      Regex.replace(~r/%{(\w+)}/, message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
