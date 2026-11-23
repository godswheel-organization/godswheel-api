defmodule GodsWheelWeb.PasswordResetController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Accounts
  alias GodsWheelWeb.Response

  def request(conn, %{"email" => email}) when is_binary(email) do
    if valid_email?(email) do
      :ok = Accounts.request_password_reset(email)

      json(
        conn,
        Response.success(%{
          message:
            "If an account exists for that email, password reset instructions will be sent."
        })
      )
    else
      invalid_email_response(conn)
    end
  end

  def request(conn, _params), do: invalid_email_response(conn)

  def reset(conn, %{"token" => token, "password" => password})
      when is_binary(token) and is_binary(password) do
    case Accounts.reset_password(token, password) do
      {:ok, _user} ->
        json(conn, Response.success(%{message: "Password has been reset successfully."}))

      {:error, %Ecto.Changeset{} = changeset} ->
        Response.send_error(
          conn,
          :unprocessable_entity,
          "validation_error",
          "The new password does not meet the requirements.",
          %{fields: Response.validation_errors(changeset)}
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

  def reset(conn, params) do
    fields =
      %{}
      |> maybe_add_field_error(params, "token", "is required and must be a string")
      |> maybe_add_field_error(params, "password", "is required and must be a string")

    Response.send_error(
      conn,
      :unprocessable_entity,
      "validation_error",
      "Provide both token and password as strings.",
      %{fields: fields}
    )
  end

  defp maybe_add_field_error(errors, params, field, message) do
    case params[field] do
      value when is_binary(value) and value != "" -> errors
      _ -> Map.put(errors, field, [message])
    end
  end

  defp valid_email?(email), do: Regex.match?(~r/^[^\s]+@[^\s]+\.[^\s]+$/, String.trim(email))

  defp invalid_email_response(conn) do
    Response.send_error(
      conn,
      :unprocessable_entity,
      "invalid_email",
      "email is required and must be a valid email address.",
      %{fields: %{email: ["must be a valid email address"]}}
    )
  end
end
