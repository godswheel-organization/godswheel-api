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

  @verification_token_ttl_seconds 86_400

  def register_user(attrs) do
    changeset = User.registration_changeset(%User{}, attrs)

    if changeset.valid? do
      Repo.transaction(fn ->
        case Repo.insert(changeset) do
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
    else
      {:error, changeset}
    end
  end

  def change_password(id, current_session_id, current_password, new_password)
      when is_binary(id) and is_binary(current_session_id) and is_binary(current_password) and
             is_binary(new_password) do
    Repo.transaction(fn ->
      case Repo.get(User, id) do
        %User{} = user ->
          if Bcrypt.verify_pass(current_password, user.password_hash) do
            changeset = User.password_changeset(user, %{password: new_password})

            case Repo.update(changeset) do
              {:ok, updated_user} ->
                now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

                Repo.update_all(
                  from(session in UserSession,
                    where:
                      session.user_id == ^user.id and session.id != ^current_session_id and
                        session.is_valid == true
                  ),
                  set: [is_valid: false, revoked_at: now]
                )

                updated_user

              {:error, changeset} ->
                Repo.rollback(changeset)
            end
          else
            Repo.rollback(:wrong_credentials)
          end

        nil ->
          Repo.rollback(:not_found)
      end
    end)
    |> case do
      {:ok, updated_user} -> {:ok, updated_user}
      {:error, reason} -> {:error, reason}
    end
  end

  def change_password(_id, _session_id, _current_password, _new_password),
    do: {:error, :invalid_arguments}

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

  def create_user_session(%User{} = user, session_id, access_token)
      when is_binary(session_id) and is_binary(access_token) do
    %UserSession{}
    |> Ecto.Changeset.change(
      id: session_id,
      user_id: user.id,
      token_hash: hash_token(access_token),
      is_valid: true
    )
    |> Repo.insert()
  end

  def active_session?(session_id, access_token)
      when is_binary(session_id) and is_binary(access_token) do
    token_hash = hash_token(access_token)

    Repo.exists?(
      from session in UserSession,
        where:
          session.id == ^session_id and session.token_hash == ^token_hash and
            session.is_valid == true and is_nil(session.revoked_at)
    )
  end

  def active_session?(_session_id, _access_token), do: false

  def revoke_user_session(session_id) when is_binary(session_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.update_all(
      from(session in UserSession,
        where: session.id == ^session_id and session.is_valid == true
      ),
      set: [is_valid: false, revoked_at: now]
    )

    :ok
  end

  def revoke_all_user_sessions(user_id) when is_binary(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.update_all(
      from(session in UserSession,
        where: session.user_id == ^user_id and session.is_valid == true
      ),
      set: [is_valid: false, revoked_at: now]
    )

    :ok
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
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    cooldown_seconds = Application.get_env(:godswheel, :verification_resend_cooldown_seconds, 60)

    result =
      Repo.transaction(fn ->
        user =
          Repo.one(
            from user in User,
              where: user.email == ^normalized_email,
              lock: "FOR UPDATE"
          )

        case user do
          %User{email_verified_at: nil} = unverified_user ->
            recent_token_at =
              Repo.one(
                from token in EmailVerificationToken,
                  where: token.user_id == ^unverified_user.id,
                  order_by: [desc: token.inserted_at],
                  limit: 1,
                  select: token.inserted_at
              )

            if recent_token_at &&
                 DateTime.diff(now, recent_token_at, :second) < cooldown_seconds do
              :rate_limited
            else
              {unverified_user, create_email_verification_token!(unverified_user)}
            end

          _ ->
            :not_applicable
        end
      end)

    case result do
      {:ok, {user, raw_token}} ->
        case deliver_verification_email(user, raw_token) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error("Unable to deliver email verification: #{inspect(reason)}")
            invalidate_verification_token(raw_token)
            :ok
        end

      {:ok, :rate_limited} ->
        :ok

      {:ok, :not_applicable} ->
        :ok

      {:error, reason} ->
        Logger.error("Unable to process verification email request: #{inspect(reason)}")
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

  defp deliver_verification_email(user, token) do
    frontend_url =
      Application.get_env(:godswheel, :frontend_url, "http://localhost:3000")
      |> String.trim_trailing("/")

    verification_url = frontend_url <> "/verify-email?token=" <> URI.encode_www_form(token)

    app_url = String.trim_trailing(frontend_url, "/")
    template = GodsWheel.EmailTemplates.verification_email(user, verification_url, app_url)

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
      |> Swoosh.Email.subject("Confirm your email for GodsWheel")
      |> Swoosh.Email.text_body(template.text)
      |> Swoosh.Email.html_body(template.html)

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

  defp password_reset_token_ttl_seconds do
    Application.get_env(:godswheel, :password_reset_token_ttl_seconds, 900)
  end

  defp create_password_reset_token(user) do
    raw_token = generate_token()
    token_hash = hash_token(raw_token)
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    expires_at =
      DateTime.add(now, password_reset_token_ttl_seconds(), :second)

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
          :ok ->
            :ok

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
    frontend_url =
      Application.get_env(:godswheel, :frontend_url, "http://localhost:3000")
      |> String.trim_trailing("/")

    reset_url = frontend_url <> "/reset-password?token=" <> URI.encode_www_form(token)

    template =
      GodsWheel.EmailTemplates.password_reset_email(
        user,
        reset_url,
        frontend_url,
        password_reset_token_ttl_seconds()
      )

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
      |> Swoosh.Email.subject("Reset your GodsWheel password")
      |> Swoosh.Email.text_body(template.text)
      |> Swoosh.Email.html_body(template.html)

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
              where: session.user_id == ^user.id and session.is_valid == true
            ),
            set: [is_valid: false, revoked_at: now]
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
