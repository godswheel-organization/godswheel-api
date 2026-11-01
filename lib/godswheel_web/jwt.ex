defmodule GodsWheelWeb.JWT do
  @moduledoc false

  @issuer "godswheel-api"
  @ttl_seconds 3_600

  def sign(user, session_id) do
    now = System.system_time(:second)

    claims = %{
      "iss" => @issuer,
      "sub" => user.id,
      "sid" => session_id,
      "iat" => now,
      "exp" => now + @ttl_seconds
    }

    with {:ok, header} <- encode_segment(%{"alg" => "HS256", "typ" => "JWT"}),
         {:ok, payload} <- encode_segment(claims) do
      signing_input = header <> "." <> payload

      signature =
        :crypto.mac(:hmac, :sha256, secret(), signing_input)
        |> Base.url_encode64(padding: false)

      {:ok, signing_input <> "." <> signature, claims}
    end
  end

  def verify(token) when is_binary(token) do
    with [header_segment, payload_segment, signature_segment] <- String.split(token, "."),
         {:ok, header_json} <- Base.url_decode64(header_segment, padding: false),
         {:ok, %{"alg" => "HS256", "typ" => "JWT"}} <- Jason.decode(header_json),
         signing_input = header_segment <> "." <> payload_segment,
         {:ok, provided_signature} <- Base.url_decode64(signature_segment, padding: false),
         expected_signature = :crypto.mac(:hmac, :sha256, secret(), signing_input),
         true <- secure_compare(provided_signature, expected_signature),
         {:ok, payload_json} <- Base.url_decode64(payload_segment, padding: false),
         {:ok, claims} <- Jason.decode(payload_json),
         true <- claims["iss"] == @issuer,
         true <- is_binary(claims["sub"]),
         true <- is_binary(claims["sid"]),
         true <- is_integer(claims["exp"]),
         true <- claims["exp"] > System.system_time(:second) do
      {:ok, claims}
    else
      _ -> {:error, :invalid_token}
    end
  end

  def verify(_token), do: {:error, :invalid_token}

  def ttl_seconds, do: @ttl_seconds

  defp encode_segment(value) do
    value
    |> Jason.encode()
    |> case do
      {:ok, json} -> {:ok, Base.url_encode64(json, padding: false)}
      error -> error
    end
  end

  defp secret, do: Application.fetch_env!(:godswheel, :jwt_secret)

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    :crypto.hash_equals(left, right)
  end

  defp secure_compare(_left, _right), do: false
end
