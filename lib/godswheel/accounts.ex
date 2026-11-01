defmodule GodsWheel.Accounts do
  import Ecto.Query, warn: false

  require Logger

  alias GodsWheel.Accounts.{
    EmailVerificationToken,
    PasswordResetToken,
    User,
    UserSession
  }

  alias GodsWheel.Repo

  @reset_token_ttl_seconds 3_600
  @verification_token_ttl_seconds 86_400

  def register_user(attrs) do
    Repo.transaction(fn ->
      case %User{}
           |> User.registration_changeset(attrs)
           |> Repo.insert() do
        {:ok, user} ->
          token = create_email_verification_token!(user)
          {user, token}

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, {user, token}} ->
        case deliver_verification_email(user, token) do
          :ok ->
            {:ok, user}

          {:error, reason} ->
            Logger.error("Unable to deliver email verification: #{inspect(reason)}")
            invalidate_verification_token(token)
            {:ok, user}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def authenticate(email, password)
      when is_binary(email) and is_binary(password) do
    normalized_email = email |> String.trim() |> String.downcase()

    user =
      Repo.one(
        from user in User,
          where: user.email == ^normalized_email
      )

    if user && Bcrypt.verify_pass(password, user.password_hash) do
      if user.email_verified_at do
        {:ok, user}
      else
        {:error, :email_not_verified}
      end
    else
      Bcrypt.no_user_verify()
      {:error, :invalid_credentials}
    end
  end

  def authenticate(_identifier, _password) do
    Bcrypt.no_user_verify()
    {:error, :invalid_credentials}
  end

  def get_user(id) when is_binary(id), do: Repo.get(User, id)

  def create_user_session(%User{} = user) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    refresh_token = generate_token()
    absolute_expires_at = DateTime.add(now, session_absolute_ttl_seconds(), :second)
    expires_at =
      min_datetime(DateTime.add(now, session_idle_ttl_seconds(), :second), absolute_expires_at)

    result =
      %UserSession{}
      |> Ecto.Changeset.change(
        user_id: user.id,
        refresh_token_hash: hash_token(refresh_token),
        expires_at: expires_at,
        absolute_expires_at: absolute_expires_at,
        last_used_at: now
      )
      |> Repo.insert()

    case result do
      {:ok, session} -> {:ok, session, refresh_token}
      {:error, reason} -> {:error, reason}
    end
  end

  def rotate_user_session(refresh_token) when is_binary(refresh_token) do
    token_hash = hash_token(refresh_token)
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.transaction(fn ->
      session =
        Repo.one(
          from session in UserSession,
            where:
              session.refresh_token_hash == ^token_hash and is_nil(session.revoked_at) and
                session.expires_at > ^now and session.absolute_expires_at > ^now,
            lock: "FOR UPDATE"
        )

      if is_nil(session) do
        Repo.rollback(:invalid_session)
      end

      user = Repo.get!(User, session.user_id)
      new_refresh_token = generate_token()
      new_expires_at =
        min_datetime(
          DateTime.add(now, session_idle_ttl_seconds(), :second),
          session.absolute_expires_at
        )

      case session
           |> Ecto.Changeset.change(
             refresh_token_hash: hash_token(new_refresh_token),
             expires_at: new_expires_at,
             last_used_at: now
           )
           |> Repo.update() do
        {:ok, updated_session} -> {user, updated_session, new_refresh_token}
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  def rotate_user_session(_refresh_token), do: {:error, :invalid_session}

  def active_session?(session_id) when is_binary(session_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.exists?(
      from session in UserSession,
        where:
          session.id == ^session_id and is_nil(session.revoked_at) and
            session.expires_at > ^now and session.absolute_expires_at > ^now
    )
  end

  def revoke_user_session(session_id) when is_binary(session_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.update_all(
      from(session in UserSession,
        where: session.id == ^session_id and is_nil(session.revoked_at)
      ),
      set: [revoked_at: now]
    )

    :ok
  end

  def revoke_all_user_sessions(user_id) when is_binary(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.update_all(
      from(session in UserSession,
        where: session.user_id == ^user_id and is_nil(session.revoked_at)
      ),
      set: [revoked_at: now]
    )

    :ok
  end

  defp session_idle_ttl_seconds do
    Application.get_env(:godswheel, :session_idle_ttl_seconds, 2_592_000)
  end

  defp session_absolute_ttl_seconds do
    Application.get_env(:godswheel, :session_absolute_ttl_seconds, 7_776_000)
  end

  defp min_datetime(left, right) do
    if DateTime.compare(left, right) == :lt, do: left, else: right
  end

  def verify_email(token) when is_binary(token) do
    token_hash = hash_token(token)
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.transaction(fn ->
      verification_token =
        Repo.one(
          from token in EmailVerificationToken,
            where:
              token.token_hash == ^token_hash and is_nil(token.used_at) and
                token.expires_at > ^now,
            lock: "FOR UPDATE"
        )

      if is_nil(verification_token) do
        Repo.rollback(:invalid_or_expired_token)
      end

      user = Repo.get!(User, verification_token.user_id)

      case user
           |> Ecto.Changeset.change(email_verified_at: now)
           |> Repo.update() do
        {:ok, verified_user} ->
          Repo.update_all(
            from(token in EmailVerificationToken,
              where: token.user_id == ^user.id and is_nil(token.used_at)
            ),
            set: [used_at: now]
          )

          verified_user

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, user} -> {:ok, user}
      {:error, reason} -> {:error, reason}
    end
  end

  def verify_email(_token), do: {:error, :invalid_or_expired_token}

  def resend_verification_email(email) when is_binary(email) do
    normalized_email = email |> String.trim() |> String.downcase()

    case Repo.get_by(User, email: normalized_email) do
      %User{email_verified_at: nil} = user ->
        token = create_email_verification_token(user)

        case token do
          {:ok, raw_token} ->
            case deliver_verification_email(user, raw_token) do
              :ok -> :ok
              {:error, reason} ->
                Logger.error("Unable to deliver email verification: #{inspect(reason)}")
                invalidate_verification_token(raw_token)
                :ok
            end

          {:error, reason} ->
            Logger.error("Unable to create email verification token: #{inspect(reason)}")
            :ok
        end

      _ ->
        :ok
    end
  end

  def resend_verification_email(_email), do: :ok

  def request_password_reset(email) when is_binary(email) do
    normalized_email = email |> String.trim() |> String.downcase()

    case Repo.get_by(User, email: normalized_email) do
      %User{email_verified_at: verified_at} = user when not is_nil(verified_at) ->
        create_password_reset_token(user)

      _ ->
        :ok
    end
  end

  def request_password_reset(_email), do: :ok

  defp create_email_verification_token!(user) do
    raw_token = generate_token()
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.update_all(
      from(token in EmailVerificationToken,
        where: token.user_id == ^user.id and is_nil(token.used_at)
      ),
      set: [used_at: now]
    )

    %EmailVerificationToken{}
    |> Ecto.Changeset.change(
      user_id: user.id,
      token_hash: hash_token(raw_token),
      expires_at: DateTime.add(now, @verification_token_ttl_seconds, :second)
    )
    |> Repo.insert!()

    raw_token
  end

  defp create_email_verification_token(user) do
    Repo.transaction(fn -> create_email_verification_token!(user) end)
    |> case do
      {:ok, token} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp deliver_verification_email(user, token) do
    frontend_url = Application.get_env(:godswheel, :frontend_url, "http://localhost:3000")
    verification_url = frontend_url <> "/verify-email?token=" <> URI.encode_www_form(token)

    email =
      Swoosh.Email.new()
      |> Swoosh.Email.to({user.full_name, user.email})
      |> Swoosh.Email.from(
        Application.get_env(
          :godswheel,
          :from_email,
          {"Godswheel", "no-reply@godswheel.app"}
        )
      )
      |> Swoosh.Email.subject("Verify your Godswheel email")
      |> Swoosh.Email.text_body(
        "Welcome to Godswheel. Verify your email within 24 hours using this link:\n#{verification_url}\n\nIf you did not create this account, you can ignore this email."
      )

    case GodsWheel.Mailer.deliver(email) do
      {:ok, _metadata} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp invalidate_verification_token(raw_token) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.update_all(
      from(token in EmailVerificationToken,
        where: token.token_hash == ^hash_token(raw_token)
      ),
      set: [used_at: now]
    )
  end

  defp create_password_reset_token(user) do
    raw_token = generate_token()
    token_hash = hash_token(raw_token)
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    expires_at = DateTime.add(now, @reset_token_ttl_seconds, :second)

    result =
      Repo.transaction(fn ->
        Repo.update_all(
          from(token in PasswordResetToken,
            where: token.user_id == ^user.id and is_nil(token.used_at)
          ),
          set: [used_at: now]
        )

        %PasswordResetToken{}
        |> Ecto.Changeset.change(
          user_id: user.id,
          token_hash: token_hash,
          expires_at: expires_at
        )
        |> Repo.insert!()
      end)

    case result do
      {:ok, _reset_token} ->
        case deliver_password_reset_email(user, raw_token) do
          :ok -> :ok
          {:error, reason} ->
            Logger.error("Unable to deliver password reset email: #{inspect(reason)}")

            Repo.update_all(
              from(token in PasswordResetToken, where: token.token_hash == ^token_hash),
              set: [used_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)]
            )

            :ok
        end

      {:error, _reason} ->
        :ok
    end
  end

  defp deliver_password_reset_email(user, token) do
    frontend_url = Application.get_env(:godswheel, :frontend_url, "http://localhost:3000")
    reset_url = frontend_url <> "/reset-password?token=" <> URI.encode_www_form(token)

    email =
      Swoosh.Email.new()
      |> Swoosh.Email.to({user.full_name, user.email})
      |> Swoosh.Email.from(
        Application.get_env(
          :godswheel,
          :from_email,
          {"Godswheel", "no-reply@godswheel.app"}
        )
      )
      |> Swoosh.Email.subject("Reset your Godswheel password")
      |> Swoosh.Email.text_body(
        "We received a request to reset your Godswheel password.\n\nUse this link within one hour:\n#{reset_url}\n\nIf you did not request this, you can ignore this email."
      )

    case GodsWheel.Mailer.deliver(email) do
      {:ok, _metadata} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def reset_password(token, password) when is_binary(token) and is_binary(password) do
    token_hash = hash_token(token)
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.transaction(fn ->
      reset_token =
        Repo.one(
          from token in PasswordResetToken,
            where:
              token.token_hash == ^token_hash and is_nil(token.used_at) and
                token.expires_at > ^now,
            lock: "FOR UPDATE"
        )

      if is_nil(reset_token) do
        Repo.rollback(:invalid_or_expired_token)
      end

      user = Repo.get!(User, reset_token.user_id)

      case User.password_changeset(user, %{password: password}) |> Repo.update() do
        {:ok, updated_user} ->
          Repo.update_all(
            from(token in PasswordResetToken,
              where: token.user_id == ^user.id and is_nil(token.used_at)
            ),
            set: [used_at: now]
          )

          Repo.update_all(
            from(session in UserSession,
              where: session.user_id == ^user.id and is_nil(session.revoked_at)
            ),
            set: [revoked_at: now]
          )

          updated_user

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, user} -> {:ok, user}
      {:error, reason} -> {:error, reason}
    end
  end

  def reset_password(_token, _password), do: {:error, :invalid_or_expired_token}

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
  end
end
