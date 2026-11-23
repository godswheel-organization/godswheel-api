defmodule GodsWheel.Storage do
  @moduledoc """
  Provider-independent interface for object storage operations.
  """

  @spec playback_url(String.t()) ::
          {:ok, %{url: String.t(), expires_at: String.t()}}
          | {:error, :invalid_audio_key | :storage_not_configured}
  def playback_url(audio_url) do
    case URI.parse(audio_url) do
      %URI{scheme: scheme} when scheme in ["http", "https"] ->
        {:ok, %{url: audio_url, expires_at: nil}}

      _ ->
        adapter().playback_url(audio_url)
    end
  end

  defp adapter do
    Application.get_env(:godswheel, :storage_adapter, GodsWheel.Storage.Tigris)
  end
end
