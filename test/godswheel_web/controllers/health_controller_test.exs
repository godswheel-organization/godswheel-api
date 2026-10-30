defmodule GodsWheelWeb.HealthControllerTest do
  use GodsWheelWeb.ConnCase, async: true

  describe "GET /api/health" do
    test "returns the application health status", %{conn: conn} do
      response =
        conn
        |> get("/api/health")
        |> json_response(:ok)

      assert response == %{"data" => %{"status" => "ok"}}
    end
  end

  describe "unknown routes" do
    test "redirects browser requests to Swagger UI", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/this-route-does-not-exist")

      assert redirected_to(conn, :found) == "/swagger"
    end

    test "returns 405 when a known route is requested with an unsupported method", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/health")

      assert json_response(conn, :method_not_allowed)["error"]["code"] ==
               "method_not_allowed"

      assert get_resp_header(conn, "allow") == ["GET"]
    end

    test "returns a JSON 404 for API clients", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/this-route-does-not-exist")
        |> json_response(:not_found)

      assert response["error"]["code"] == "not_found"
    end
  end
end
