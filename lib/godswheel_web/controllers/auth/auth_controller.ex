defmodule GodsWheelWeb.AuthController do
  use GodsWheelWeb, :controller

  alias GodsWheel.Accounts
  alias GodsWheelWeb.{JWT, Response}

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
        if duplicate_email?(changeset) do
          Response.send_error(
            conn,
            :conflict,
            "email_already_registered",
            "An account with this email address already exists.",
            %{fields: Response.validation_errors(changeset)}
          )
        else
          Response.send_error(
            conn,
            :unprocessable_entity,
            "validation_error",
            "The submitted account details are invalid.",
            %{fields: Response.validation_errors(changeset)}
          )
        end
    end
  end

  def change_password(
        conn,
        %{
          "current_password" => current_password,
          "new_password" => new_password
        }
      )
      when is_binary(current_password) and is_binary(new_password) do
    case Accounts.change_password(
           conn.assigns.current_user.id,
           conn.assigns.current_session_id,
           current_password,
           new_password
         ) do
      {:ok, _updated_user} ->
        Response.send_success(
          conn,
          :ok,
          %{
            message:
              "Your password was successfully changed. Other active sessions have been logged out."
          }
        )

      {:error, :not_found} ->
        Response.send_error(
          conn,
          :not_found,
          "not_found",
          "User not found.",
          "Check that your session is still valid."
        )

      {:error, :wrong_credentials} ->
        Response.send_error(
          conn,
          :forbidden,
          "wrong_credentials",
          "The current password is incorrect.",
          "Enter your current password correctly and try again."
        )

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
          :server_error,
          "password_change_failed",
          "Unable to change your password right now. Please try again."
        )
    end
  end

  def change_password(conn, params) do
    fields =
      %{}
      |> maybe_add_field_error(params, "current_password", "is required and must be a string")
      |> maybe_add_field_error(params, "new_password", "is required and must be a string")

    Response.send_error(
      conn,
      :unprocessable_entity,
      "validation_error",
      "Provide both current_password and new_password as strings.",
      %{fields: fields}
    )
  end

  def login(conn, %{"email" => identifier, "password" => password})
      when is_binary(identifier) and is_binary(password) and password != "" do
    if valid_email?(identifier) do
      authenticate_and_respond(conn, identifier, password)
    else
      Response.send_error(
        conn,
        :unprocessable_entity,
        "invalid_credentials_input",
        "email must be a valid email address.",
        %{fields: %{email: ["must be a valid email address"]}}
      )
    end
  end

  def login(conn, params) do
    fields =
      %{}
      |> maybe_add_field_error(params, "email", "must be a valid email address")
      |> maybe_add_field_error(params, "password", "is required and must be a non-empty string")

    Response.send_error(
      conn,
      :unprocessable_entity,
      "invalid_credentials_input",
      "Provide a valid email address and a password.",
      %{fields: fields}
    )
  end

  defp authenticate_and_respond(conn, identifier, password) do
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

  def logout(conn, _params) do
    :ok = Accounts.revoke_user_session(conn.assigns.current_session_id)

    json(conn, Response.success(%{message: "Logged out successfully."}))
  end

  def logout_all(conn, _params) do
    :ok = Accounts.revoke_all_user_sessions(conn.assigns.current_user.id)

    json(conn, Response.success(%{message: "All sessions have been logged out."}))
  end

  def resend_verification(conn, %{"email" => email}) when is_binary(email) do
    if valid_email?(email) do
      :ok = Accounts.resend_verification_email(email)

      json(
        conn,
        Response.success(%{
          message:
            "If an unverified account exists for that email, a verification email will be sent."
        })
      )
    else
      invalid_email_response(conn)
    end
  end

  def resend_verification(conn, _params), do: invalid_email_response(conn)

  def me(conn, _params) do
    render(conn, :user, user: conn.assigns.current_user)
  end

  defp issue_session(conn, user) do
    session_id = Ecto.UUID.generate()

    with {:ok, access_token, claims} <- JWT.sign(user, session_id),
         {:ok, _session} <- Accounts.create_user_session(user, session_id, access_token) do
      render(conn, :session, user: user, token: access_token, claims: claims)
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

  defp public_user(user) do
    %{
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      email_verified: not is_nil(user.email_verified_at)
    }
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

  defp duplicate_email?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:email, {_message, opts}} ->
        Keyword.get(opts, :constraint) == :unique

      _ ->
        false
    end)
  end
end
