defmodule TuskarrWeb.PasswordController do
  use TuskarrWeb, :controller

  action_fallback TuskarrWeb.FallbackController
  alias Tuskarr.{Accounts, Accounts.User}

  def new(conn, %{"email" => email} = params) do
    with {:ok, %User{} = user} <- Accounts.get_confirmed_user_by_email(email) do
      with {:ok, %User{} = user} <- Accounts.update_user(user, %{recovery_password_token: UUID.uuid4(:hex)}) do
        #send email
        case Tuskarr.Mailer.recovery_password(user) do
          {:ok, _}                 -> IO.inspect("Sending mail to #{user.name} saccessfully")
          {:error, _code, message} -> IO.inspect("Seinding mail error #{message}")
        end

        conn
        |> put_status(:ok)
        |> json(%{ok: true})
      end
    end
  end

  def update(conn, %{"new_password" => new_password, "recovery_token" => recovery_token}) do
    with{:ok, %User{} = user} <- Accounts.get_user_by_token(recovery_token) do
      with {:ok, %User{} = user} <- Accounts.update_password(user, %{"password" => new_password, "by_email" => true}) do
        render(conn, "user.json", user: user)
      end
    end
  end

end
