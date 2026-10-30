defmodule GodsWheelWeb.PasswordResetController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Accounts

  def request(conn, %{"email" => email}) do
    :ok = Accounts.request_password_reset(email)

    json(conn, %{
      data: %{
        message: "If an account exists for that email, password reset instructions will be sent."
      }
    })
  end

  def request(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{message: "email is required"}})
  end

  def reset(conn, %{"token" => token, "password" => password}) do
    case Accounts.reset_password(token, password) do
      {:ok, _user} -> json(conn, %{data: %{message: "Password has been reset successfully."}})
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)})

      {:error, _reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{message: "The password reset token is invalid or expired."}})
    end
  end

  def reset(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{message: "token and password are required"}})
  end
end
