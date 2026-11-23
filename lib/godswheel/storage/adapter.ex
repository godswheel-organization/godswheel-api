defmodule GodsWheel.Storage.Adapter do
  @callback playback_url(object_key :: String.t()) ::
              {:ok, %{url: String.t(), expires_at: String.t()}}
              | {:error, :invalid_audio_key | :storage_not_configured}
end
