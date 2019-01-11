defmodule TuskarrWeb.SessionController do
  use TuskarrWeb, :controller
  use Guardian.Phoenix.Controller

  action_fallback TuskarrWeb.FallbackController
  alias Tuskarr.{Accounts.Session, Accounts.Socials}


  def create(conn, %{"email" => email, "password" => password}, _user, _claims) do
    with {:ok, user} <- Session.find_user(email, password) do
      {:ok, jwt} = Session.sign(conn, user)

      render(conn, "user.json", user: user, jwt: jwt)
    end
  end

  def facebook(conn, %{"fb_token" => token}, user, _claims) do
    with {:ok, info} <- FacebookApi.get_info(token) do
      with {:ok, user} <- Socials.provisions(info, user, :facebook) do
        {:ok, jwt} = Session.sign(conn, user)

        render(conn, "user.json", user: user, jwt: jwt)
      end
    end
  end

  def google(conn, %{"google_token" => token}, user, _claims) do
    with {:ok, info} <- GoogleApi.get_info(token) do
      with {:ok, user} <- Socials.provisions(info, user, :google) do
        {:ok, jwt} = Session.sign(conn, user)

        render(conn, "user.json", user: user, jwt: jwt)
      end
    end
  end

  def unauthenticated(conn, _params, _hendler) do
    conn
    |> put_status(401)
    |> json(%{ message: "Authentication required" })
  end

end
