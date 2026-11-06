defmodule GodsWheel.Sermons.ProgressBuffer do
  use GenServer

  require Logger

  alias GodsWheel.Repo
  alias GodsWheel.Sermons.SermonProgress

  import Ecto.Query

  @default_flush_interval_ms 300_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put(user_id, sermon_id, position_seconds) do
    GenServer.call(__MODULE__, {:put, user_id, sermon_id, position_seconds})
  end

  @impl true
  def init(opts) do
    interval =
      Keyword.get(
        opts,
        :flush_interval_ms,
        Application.get_env(
          :godswheel,
          :sermon_progress_flush_interval_ms,
          @default_flush_interval_ms
        )
      )

    schedule_flush(interval)

    {:ok, %{buffer: %{}, flush_interval_ms: interval}}
  end

  @impl true
  def handle_call({:put, user_id, sermon_id, position_seconds}, _from, state) do
    now = DateTime.utc_now()

    entry = %{
      id: Ecto.UUID.generate(),
      user_id: user_id,
      sermon_id: sermon_id,
      position_seconds: position_seconds,
      position_updated_at: now,
      inserted_at: now,
      updated_at: now
    }

    key = {user_id, sermon_id}
    buffer = Map.put(state.buffer, key, entry)

    progress = %SermonProgress{
      user_id: user_id,
      sermon_id: sermon_id,
      position_seconds: position_seconds,
      position_updated_at: now,
      inserted_at: now,
      updated_at: now
    }

    {:reply, {:ok, progress}, %{state | buffer: buffer}}
  end

  @impl true
  def handle_info(:flush, state) do
    state = flush_buffer(state)
    schedule_flush(state.flush_interval_ms)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    flush_buffer(state)
    :ok
  end

  defp flush_buffer(%{buffer: buffer} = state) when map_size(buffer) == 0, do: state

  defp flush_buffer(state) do
    pending = state.buffer
    state = %{state | buffer: %{}}

    try do
      entries = Map.values(pending)

      conflict_query =
        from progress in SermonProgress,
          update: [
            set: [
              position_seconds: fragment("EXCLUDED.position_seconds"),
              position_updated_at: fragment("EXCLUDED.position_updated_at"),
              updated_at: fragment("EXCLUDED.updated_at")
            ]
          ],
          where:
            fragment(
              "EXCLUDED.position_updated_at >= ?",
              progress.position_updated_at
            )

      Repo.insert_all(
        SermonProgress,
        entries,
        on_conflict: conflict_query,
        conflict_target: [:user_id, :sermon_id]
      )

      state
    rescue
      error ->
        Logger.error("Failed to flush sermon progress: #{Exception.message(error)}")
        %{state | buffer: merge_pending(state.buffer, pending)}
    catch
      kind, reason ->
        Logger.error("Failed to flush sermon progress: #{inspect({kind, reason})}")
        %{state | buffer: merge_pending(state.buffer, pending)}
    end
  end

  defp merge_pending(current, pending) do
    Map.merge(pending, current, fn _key, older, newer ->
      if DateTime.compare(newer.position_updated_at, older.position_updated_at) == :lt do
        older
      else
        newer
      end
    end)
  end

  defp schedule_flush(interval) do
    Process.send_after(self(), :flush, interval)
  end
end
