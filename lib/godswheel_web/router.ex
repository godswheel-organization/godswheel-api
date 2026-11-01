defmodule GodsWheelWeb.Router do
  use GodsWheelWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated_api do
    plug GodsWheelWeb.Plugs.Authenticate
  end

  pipeline :same_origin_api do
    plug GodsWheelWeb.Plugs.VerifyOrigin
  end

  pipeline :dashboard do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug GodsWheelWeb.Plugs.DashboardAuth
  end

  pipeline :fallback do
    plug :accepts, ["html"]
  end

  scope "/api/v1", GodsWheelWeb do
    pipe_through :api

    get "/health", HealthController, :show
    get "/sermons", Sermon.SermonController, :index
    get "/sermons/:id", Sermon.SermonController, :show
    get "/categories", Sermon.CategoryController, :index
    get "/speakers", Sermon.SpeakerController, :index
    post "/auth/signup", AuthController, :signup
    post "/auth/login", AuthController, :login
    post "/auth/verify-email", AuthController, :verify_email
    post "/auth/resend-verification", AuthController, :resend_verification
    post "/auth/forgot-password", PasswordResetController, :request
    post "/auth/reset-password", PasswordResetController, :reset
  end

  scope "/api/v1", GodsWheelWeb do
    pipe_through [:api, :authenticated_api]

    get "/auth/me", AuthController, :me
    post "/auth/logout", AuthController, :logout
    post "/auth/logout-all", AuthController, :logout_all
  end

  scope "/api/v1/auth", GodsWheelWeb do
    pipe_through [:api, :same_origin_api]

    post "/refresh", AuthController, :refresh
  end

  get "/api/v1/openapi.json", GodsWheelWeb.OpenApiController, :spec
  get "/swagger", GodsWheelWeb.OpenApiController, :swagger_ui

  import Phoenix.LiveDashboard.Router

  scope "/admin" do
    pipe_through :dashboard

    live_dashboard "/dashboard", metrics: GodsWheelWeb.Telemetry
  end

  if Application.compile_env(:godswheel, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  scope "/", GodsWheelWeb do
    pipe_through :fallback

    match :*, "/", OpenApiController, :swagger_ui
    match :*, "/*path", OpenApiController, :swagger_ui
  end
end
