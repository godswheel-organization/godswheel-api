defmodule GodsWheelWeb.AuthControllerTest do
  use GodsWheelWeb.ConnCase, async: false
  import Swoosh.TestAssertions

  alias GodsWheel.Accounts
  alias GodsWheel.Accounts.User
  alias GodsWheel.Repo

  describe "POST /api/auth/signup" do
    test "creates an unverified user and does not return an access token", %{conn: conn} do
      response =
        conn
        |> post("/api/auth/signup", %{
          "full_name" => "Nature Okoye",
          "email" => "Nature@example.com",
          "username" => "Nature_Dev",
          "password" => "a-strong-password"
        })
        |> json_response(:created)

      assert response["data"]["user"]["email"] == "nature@example.com"
      assert response["data"]["user"]["username"] == "nature_dev"
      assert response["data"]["user"]["email_verified"] == false
      refute Map.has_key?(response["data"], "access_token")

      user = Repo.get_by!(User, email: "nature@example.com")
      assert is_nil(user.email_verified_at)
      assert_email_sent(fn email -> email.subject == "Verify your Godswheel email" end)
    end

    test "rejects missing required fields", %{conn: conn} do
      response =
        conn
        |> post("/api/auth/signup", %{"email" => "person@example.com"})
        |> json_response(:unprocessable_entity)

      assert response["errors"]["full_name"]
      assert response["errors"]["username"]
      assert response["errors"]["password"]
    end
  end

  describe "POST /api/auth/login" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          full_name: "Test User",
          email: "test@example.com",
          username: "test_user",
          password: "a-strong-password"
        })

      user =
        user
        |> Ecto.Changeset.change(email_verified_at: DateTime.utc_now())
        |> Repo.update!()

      %{user: user}
    end

    test "authenticates with email", %{conn: conn} do
      response =
        conn
        |> post("/api/auth/login", %{
          "identifier" => "TEST@example.com",
          "password" => "a-strong-password"
        })
        |> json_response(:ok)

      assert response["data"]["user"]["email"] == "test@example.com"
      assert response["data"]["access_token"]
    end

    test "authenticates with username", %{conn: conn} do
      response =
        conn
        |> post("/api/auth/login", %{
          "identifier" => "TEST_USER",
          "password" => "a-strong-password"
        })
        |> json_response(:ok)

      assert response["data"]["user"]["username"] == "test_user"
    end

    test "returns a generic error for invalid credentials", %{conn: conn} do
      response =
        conn
        |> post("/api/auth/login", %{
          "identifier" => "test@example.com",
          "password" => "incorrect-password"
        })
        |> json_response(:unauthorized)

      assert response["error"]["message"] == "Invalid email/username or password"
    end
  end

  describe "email verification" do
    test "does not allow an unverified user to log in", %{conn: conn} do
      {:ok, _user} =
        Accounts.register_user(%{
          full_name: "Unverified User",
          email: "unverified@example.com",
          username: "unverified_user",
          password: "a-strong-password"
        })

      response =
        conn
        |> post("/api/auth/login", %{
          "identifier" => "unverified@example.com",
          "password" => "a-strong-password"
        })
        |> json_response(:forbidden)

      assert response["error"]["code"] == "email_not_verified"
    end

    test "rejects an invalid verification token", %{conn: conn} do
      response =
        conn
        |> post("/api/auth/verify-email", %{"token" => "invalid-token"})
        |> json_response(:unprocessable_entity)

      assert response["error"]["code"] == "invalid_or_expired_token"
    end
  end

  describe "authenticated endpoints" do
    test "returns 401 without a bearer token", %{conn: conn} do
      conn
      |> get("/api/auth/me")
      |> json_response(:unauthorized)
    end

    test "returns the current user with a valid bearer token", %{conn: conn} do
      {:ok, user} =
        Accounts.register_user(%{
          full_name: "Test User",
          email: "me@example.com",
          username: "me_user",
          password: "a-strong-password"
        })

      user =
        user
        |> Ecto.Changeset.change(email_verified_at: DateTime.utc_now())
        |> Repo.update!()

      {:ok, token, _claims} = GodsWheelWeb.JWT.sign(user)

      response =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/auth/me")
        |> json_response(:ok)

      assert response["data"]["id"] == user.id
      assert response["data"]["email_verified"] == true
    end
  end

  describe "POST /api/auth/forgot-password" do
    test "returns the same response for an unknown email", %{conn: conn} do
      response =
        conn
        |> post("/api/auth/forgot-password", %{"email" => "unknown@example.com"})
        |> json_response(:ok)

      assert response["data"]["message"] =~ "If an account exists"
    end
  end
end
