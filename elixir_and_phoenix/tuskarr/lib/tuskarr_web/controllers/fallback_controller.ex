defmodule TuskarrWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use TuskarrWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(TuskarrWeb.ChangesetView, "error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> render(TuskarrWeb.ErrorView, :"404")
  end

  def call(conn, {:error, :email_not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "email not found"})
  end

  def call(conn, {:error, :token_not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "recovery token not found"})
  end

  def call(conn, {:error, :password_is_invalid}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Password is invalid"})
  end

  def call(conn, {:error, :invalid_fb_token}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "invalide facebook token"})
  end

  def call(conn, {:error, :email_not_maching_or_not_verified}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "email not found or not verified"})
  end

  def call(conn, {:error, :email_not_presents_or_not_verified, info}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "email not presents or not_verified", info: info})
  end

  def call(conn, {:error, :invalid_google_token}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "invalid google token"})
  end

  def call(conn, {:error, :email_not_found_or_user_not_confirmed}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "email not found or user not confirmed"})
  end

  def call(conn, {:error, :cant_not_disconnect_facebook}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "can not disconnect from facebook: google connection or email/password should be present"})
  end

  def call(conn, {:error, :cant_not_disconnect_google}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "can not disconnect from google: facebook connection or email/password should be present"})
  end

  def call(conn, {:error, :user_has_email_connection}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "user has an email connection"})
  end
end
