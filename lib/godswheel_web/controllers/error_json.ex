defmodule GodsWheelWeb.ErrorJSON do
  alias GodsWheelWeb.Response

  def render(template, _assigns) do
    status = template |> String.split(".") |> List.first()
    message = Phoenix.Controller.status_message_from_template(template)
    code = error_code(status)

    Response.error(code, message)
  end

  defp error_code("400"), do: "bad_request"
  defp error_code("401"), do: "unauthorized"
  defp error_code("403"), do: "forbidden"
  defp error_code("404"), do: "not_found"
  defp error_code("405"), do: "method_not_allowed"
  defp error_code("422"), do: "unprocessable_entity"
  defp error_code(_), do: "internal_server_error"
end
