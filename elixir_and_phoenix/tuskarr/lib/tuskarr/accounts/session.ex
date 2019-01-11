defmodule Tuskarr.Accounts.Session do
  import Ecto.Query
  alias Tuskarr.Accounts.User
  alias Tuskarr.Repo

  def find_user(email, _) when is_nil(email) or length(email) == 0  do
    {:error, :email_not_found}
  end

  def find_user(email, password) do
    q = User |> where(email: ^email, by_email: true)

    user = Repo.one(q)

    if user != nil do
      case check_password(password, user) do
        true ->
          {:ok, user}
        _ ->
          {:error, :password_is_invalid}
      end
    else
      {:error, :email_not_found}
    end
  end


  def sign(conn, user) do
    jwt = Guardian.Plug.api_sign_in(conn, user) |> Guardian.Plug.current_token
    {:ok, jwt}
  end

  def check_user(password, user) do
    case check_password(password, user) do
      true ->
        {:ok, user}
      _ ->
        {:error, :password_is_invalid}
    end
  end

  #private
  defp check_password(password, %User{crypted_password: crypted_password} = user) when not is_nil(crypted_password) do
    Comeonin.Bcrypt.checkpw(password, user.crypted_password)
  end

  defp check_password(password, user) do
    {:error, :crypted_password_is_nil}
  end
end
