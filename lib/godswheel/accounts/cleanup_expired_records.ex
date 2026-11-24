defmodule GodsWheel.Accounts.CleanupExpiredRecords do
  use GenServer

  import Ecto.Query

  require Logger

  alias GodsWheel.Accounts.{EmailVerificationToken, PasswordResetToken, UserSession}
  alias GodsWheel.Repo

  @run_hour_utc 1
  @advisory_lock_id 6561
  @revoked_session_retention_days 30

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_next_run()
    cleanup_expired_records()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup_expired_records, state) do
    cleanup_expired_records()
    schedule_next_run()
    {:noreply, state}
  end

  defp cleanup_expired_records do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    result =
      Repo.transaction(fn ->
        case Repo.query!("SELECT pg_try_advisory_xact_lock($1)", [@advisory_lock_id]).rows do
          [[true]] ->
            retention_cutoff = DateTime.add(now, -@revoked_session_retention_days, :day)

            {sessions_deleted, _} =
              Repo.delete_all(
                from session in UserSession,
                  where: session.is_valid == false and session.revoked_at < ^retention_cutoff
              )

            {verification_tokens_deleted, _} =
              Repo.delete_all(
                from token in EmailVerificationToken,
                  where: token.expires_at <= ^now
              )

            {password_reset_tokens_deleted, _} =
              Repo.delete_all(
                from token in PasswordResetToken,
                  where: token.expires_at <= ^now
              )

            {:deleted, sessions_deleted, verification_tokens_deleted,
             password_reset_tokens_deleted}

          [[false]] ->
            :already_running
        end
      end)

    case result do
      {:ok, {:deleted, sessions, verification_tokens, password_reset_tokens}} ->
        Logger.info(
          "Expired record cleanup completed: \nrevoked_sessions=#{sessions}, \n" <>
            "email_verification_tokens=#{verification_tokens}, \n" <>
            "password_reset_tokens=#{password_reset_tokens}"
        )

      {:ok, :already_running} ->
        Logger.info("Expired record cleanup skipped because another instance holds the lock")

      {:error, reason} ->
        Logger.error("Expired record cleanup failed: #{inspect(reason)}")
    end
  rescue
    error ->
      Logger.error("Expired record cleanup failed: #{Exception.message(error)}")
  end

  defp schedule_next_run do
    now = DateTime.utc_now()
    today = DateTime.to_date(now)

    scheduled_today =
      DateTime.new!(today, Time.new!(@run_hour_utc, 0, 0), "Etc/UTC")

    next_run =
      if DateTime.compare(scheduled_today, now) == :gt do
        scheduled_today
      else
        tomorrow = Date.add(today, 1)
        DateTime.new!(tomorrow, Time.new!(@run_hour_utc, 0, 0), "Etc/UTC")
      end

    delay = DateTime.diff(next_run, now, :millisecond)
    Process.send_after(self(), :cleanup_expired_records, delay)
  end
end
