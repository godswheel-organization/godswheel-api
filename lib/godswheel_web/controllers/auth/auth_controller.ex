defmodule GodsWheelWeb.AuthController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Accounts
  alias GodsWheelWeb.JWT

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
        {:ok, token, claims} = JWT.sign(user)
        render(conn, :session, user: user, token: token, claims: claims)

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
        |> json(%{error: %{message: "Invalid email/username or password"}})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{message: "identifier and password are required"}})
  end

  def verify_email(conn, %{"token" => token}) do
    case Accounts.verify_email(token) do
      {:ok, user} ->
        {:ok, access_token, claims} = JWT.sign(user)
        render(conn, :session, user: user, token: access_token, claims: claims)

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
      username: user.username,
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
