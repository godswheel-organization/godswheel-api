defmodule GodsWheel.Storage.Tigris do
  @default_endpoint "https://t3.storage.dev"
  @default_region "auto"
  @default_url_ttl_seconds 14_400
  @max_url_ttl_seconds 604_800

  def playback_url(object_key) when is_binary(object_key) do
    with {:ok, config} <- storage_config(),
         {:ok, object_key} <- normalize_object_key(object_key),
         {:ok, url} <- presigned_url(config, object_key) do
      expires_at =
        DateTime.utc_now()
        |> DateTime.add(config.url_ttl_seconds, :second)
        |> DateTime.to_iso8601()

      {:ok, %{url: url, expires_at: expires_at}}
    end
  end

  def playback_url(_object_key), do: {:error, :invalid_audio_key}

  defp presigned_url(config, object_key) do
    s3_config =
      ExAws.Config.new(:s3,
        access_key_id: config.access_key_id,
        secret_access_key: config.secret_access_key,
        security_token: config.session_token,
        region: config.region,
        host: URI.parse(config.endpoint).host,
        scheme: "https://"
      )

    case ExAws.S3.presigned_url(
           s3_config,
           :get,
           config.bucket,
           object_key,
           expires_in: config.url_ttl_seconds,
           virtual_host: false
         ) do
      {:ok, url} -> {:ok, url}
      {:error, _reason} -> {:error, :storage_not_configured}
    end
  rescue
    _error -> {:error, :storage_not_configured}
  end

  defp storage_config do
    config = Application.get_env(:godswheel, :tigris, [])

    bucket = Keyword.get(config, :bucket)
    access_key_id = Keyword.get(config, :access_key_id)
    secret_access_key = Keyword.get(config, :secret_access_key)
    endpoint = Keyword.get(config, :endpoint, @default_endpoint)
    region = Keyword.get(config, :region, @default_region)
    url_ttl_seconds = Keyword.get(config, :url_ttl_seconds, @default_url_ttl_seconds)
    session_token = Keyword.get(config, :session_token)

    cond do
      not non_empty_binary?(bucket) ->
        {:error, :storage_not_configured}

      not non_empty_binary?(access_key_id) or not non_empty_binary?(secret_access_key) ->
        {:error, :storage_not_configured}

      not valid_endpoint?(endpoint) ->
        {:error, :storage_not_configured}

      not non_empty_binary?(region) ->
        {:error, :storage_not_configured}

      not is_nil(session_token) and not non_empty_binary?(session_token) ->
        {:error, :storage_not_configured}

      not is_integer(url_ttl_seconds) or url_ttl_seconds < 1 or
          url_ttl_seconds > @max_url_ttl_seconds ->
        {:error, :storage_not_configured}

      true ->
        {:ok,
         %{
           bucket: bucket,
           access_key_id: access_key_id,
           secret_access_key: secret_access_key,
           session_token: session_token,
           endpoint: String.trim_trailing(endpoint, "/"),
           region: region,
           url_ttl_seconds: url_ttl_seconds
         }}
    end
  end

  defp normalize_object_key(object_key) do
    key = String.trim(object_key)

    cond do
      key == "" ->
        {:error, :invalid_audio_key}

      String.starts_with?(key, "/") or String.contains?(key, "://") ->
        {:error, :invalid_audio_key}

      String.contains?(key, ["\\", "\0"]) ->
        {:error, :invalid_audio_key}

      true ->
        {:ok, key}
    end
  end

  defp valid_endpoint?(endpoint) when is_binary(endpoint) do
    uri = URI.parse(endpoint)

    uri.scheme == "https" and is_binary(uri.host) and is_nil(uri.userinfo) and
      uri.path in [nil, "", "/"] and is_nil(uri.query) and is_nil(uri.fragment)
  end

  defp valid_endpoint?(_endpoint), do: false

  defp non_empty_binary?(value), do: is_binary(value) and value != ""
end
