defmodule TuskarrWeb.UserController do
  use TuskarrWeb, :controller
  use Guardian.Phoenix.Controller

  alias Tuskarr.{Accounts, Accounts.User, Accounts.Session, Accounts.Socials}
  alias TuskarrWeb.SessionController

  action_fallback TuskarrWeb.FallbackController

  plug Guardian.Plug.EnsureAuthenticated, [handler: { SessionController, :unauthenticated }] when not action in [:create, :confirm]

  def create(conn, user_params, _user, _claims) do
    #TODO: password is required!!! Add to validation from this action
    with {:ok, %User{} = user} <- Accounts.create_user(user_params |> Map.put("by_email", true)) do
      {:ok, jwt} = Session.sign(conn, user)

      conn
      |> put_status(:created)
      |> render("show.json", user: user, jwt: jwt)
    end
  end

  def show(conn, _, user, _claims) do
    render(conn, "user.json", user: user)
  end

  def update(conn, user_params, user, _claims) do
    with {:ok, %User{} = user} <- Accounts.update_user(user, user_params) do
      render(conn, "user.json", user: user)
    end
  end

  def connect_email(conn, %{"email" => _email, "password" => _password} = params, user, _claims) do
    with {:ok, user} <- Accounts.connect_email(user, params) do
      render(conn, "user.json", user: user)
    end
  end

  # def delete(conn, %{"id" => id}) do
  #   user = Accounts.get_user!(id)
  #   with {:ok, %User{}} <- Accounts.delete_user(user) do
  #     send_resp(conn, :no_content, "")
  #   end
  # end

  def confirm(conn, %{"token" => token}, _user, _claims) do
    with {:ok, user} <- Accounts.get_user_by_confirm_token(token) do
      with {:ok, %User{confirmed: true}} <- Accounts.update_user(user, %{confirmed: true}) do
        render conn, "confirm.html"
      end
    end
  end


  @doc """
    Update only email of user
    params: email, password
  """
  def update_email(conn, %{"email" => email, "password" => password}, user, _claims) do
    with {:ok, %User{} = user} <- Accounts.Session.check_user(password, user) do
      with {:ok, %User{} = user} <- Accounts.update_email(user, %{"email" => email}) do
        render(conn, "user.json", user: user)
      end
    end
  end

  @doc """
    Update only password of user
    params: password, new_password
  """
  def update_password(conn, %{"password" => password, "new_password" => new_password}, user, _claims) do
    with {:ok, %User{} = user} <- Accounts.Session.check_user(password, user) do
      with {:ok, %User{} = user} <- Accounts.update_password(user, %{"password" => new_password}) do
        render(conn, "user.json", user: user)
      end
    end
  end

  @doc """
  remove facebook connect
  """
  def disconnect_facebook(conn, _params, user, _claims) do
    with {:ok, %User{} = user} <- Socials.disconnect(user, :facebook) do
      render(conn, "user.json", user: user)
    end
  end

  @doc """
  remove google connect
  """
  def disconnect_google(conn, _params, user, _claims) do
    with {:ok, %User{} = user} <- Socials.disconnect(user, :google) do
      render(conn, "user.json", user: user)
    end
  end
end
