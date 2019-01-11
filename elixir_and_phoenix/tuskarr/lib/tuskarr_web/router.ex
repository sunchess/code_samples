defmodule TuskarrWeb.Router do
  use TuskarrWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Guardian.Plug.VerifyHeader
    plug Guardian.Plug.LoadResource#, ensure: true
  end

  pipeline :auth_ensure do
    plug Guardian.Plug.EnsureResource
  end

  scope "/", TuskarrWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    get "/users/confirm", UserController, :confirm, as: :confirm_user
  end

  # Other scopes may use custom stacks.
  scope "/api", TuskarrWeb do
    pipe_through :api

    post "/users", UserController, :create

    post "/password", PasswordController, :new
    put  "/password", PasswordController, :update

    post "/session",          SessionController, :create
    post "/session/facebook", SessionController, :facebook, as: :facebook_session
    post "/session/google",   SessionController, :google, as: :google_session
  end

  scope "/api", TuskarrWeb do
    pipe_through [:api, :auth_ensure]

    put  "/users",                     UserController, :update
    get  "/users",                     UserController, :show
    put  "/users/email",               UserController, :update_email, as: :update_email_user
    put  "/users/password",            UserController, :update_password, as: :update_password_user
    put  "/users/disconnect_facebook", UserController, :disconnect_facebook, as: :disconnect_facebook_user
    put  "/users/disconnect_google",   UserController, :disconnect_google, as: :disconnect_google_user
    put  "/users/connect_email",       UserController, :connect_email, as: :connect_email_user
  end
end
