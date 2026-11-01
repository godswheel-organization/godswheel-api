defmodule GodsWheelWeb.Response do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def success(data, meta \\ nil) do
    payload = %{success: true, data: data}

    payload =
      if is_nil(meta) do
        payload
      else
        Map.put(payload, :meta, meta)
      end

    camelize_keys(payload)
  end

  def error(code, message, details \\ nil) do
    %{
      success: false,
      error: %{
        code: code,
        message: message,
        details: details
      }
    }
    |> camelize_keys()
  end

  def send_success(conn, status, data, meta \\ nil) do
    conn
    |> put_status(status)
    |> json(success(data, meta))
  end

  def send_error(conn, status, code, message, details \\ nil) do
    conn
    |> put_status(status)
    |> json(error(code, message, details))
  end

  defp camelize_keys(%_{} = struct), do: struct

  defp camelize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {camelize_key(key), camelize_keys(value)}
    end)
  end

  defp camelize_keys(list) when is_list(list), do: Enum.map(list, &camelize_keys/1)
  defp camelize_keys(value), do: value

  defp camelize_key(key) when is_atom(key), do: key |> Atom.to_string() |> camelize_key()

  defp camelize_key(key) when is_binary(key) do
    camelized = Macro.camelize(key)
    String.downcase(String.first(camelized)) <> String.slice(camelized, 1..-1//1)
  end

  defp camelize_key(key), do: key
end
