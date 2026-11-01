defmodule GodsWheelWeb.PasswordResetController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Accounts
  alias GodsWheelWeb.Response

  def request(conn, %{"email" => email}) do
    :ok = Accounts.request_password_reset(email)

    json(
      conn,
      Response.success(%{
        message:
          "If an account exists for that email, password reset instructions will be sent."
      })
    )
  end

  def request(conn, _params) do
    Response.send_error(conn, :unprocessable_entity, "missing_email", "email is required.")
  end

  def reset(conn, %{"token" => token, "password" => password}) do
    case Accounts.reset_password(token, password) do
      {:ok, _user} ->
        json(conn, Response.success(%{message: "Password has been reset successfully."}))

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)

        Response.send_error(
          conn,
          :unprocessable_entity,
          "validation_error",
          "The submitted password is invalid.",
          errors
        )

      {:error, _reason} ->
        Response.send_error(
          conn,
          :unprocessable_entity,
          "invalid_or_expired_token",
          "The password reset token is invalid or expired."
        )
    end
  end

  def reset(conn, _params) do
    Response.send_error(
      conn,
      :unprocessable_entity,
      "missing_parameters",
      "token and password are required."
    )
  end
end
