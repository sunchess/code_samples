defmodule Tuskarr.Accounts.Socials do
  @moduledoc """
  The Accounts Socials context.
  """

  import Ecto.Query, warn: false
  alias Tuskarr.Repo
  alias Tuskarr.Accounts
  alias Tuskarr.Accounts.User


  def provisions(info, user, :facebook) when not is_nil(user) do
    # {
      #   "id": "1592569374102123",
      #   "name": "Alex Dmitriev",
      #   "email": "sunchess@inbox.ru",
      #   "picture": {
      #     "data": {
      #       "is_silhouette": false,
      #       "url": "https://scontent.xx.fbcdn.net/v/t1.0-1/c45.43.538.538/s50x50/76189_171244819567926_8010140_n.jpg?oh=b184114197f21ce337963b83af174754&oe=5A353D33"
      #     }
      #   }
    # }
    if user.facebook_id == info["id"] do
      {:ok, user}
    else
      Accounts.update_user(user, %{facebook_id: info["id"], avatar: info["picture"]["data"]["url"] })
    end
  end

  def provisions(info, user, :facebook) when is_nil(user) do
    if info["email"] do

      #try find user by fb id
      case Accounts.get_user_by_fb_id(info["id"]) do
        #when email not saved
        {:ok, %User{email: nil} = user} ->
           Accounts.update_user(user, %{email: info["email"], confirmed: true, facebook_id: info["id"], avatar: info["picture"]["data"]["url"] })

        {:ok, %User{} = user} ->
           Accounts.update_user(user, %{facebook_id: info["id"], avatar: info["picture"]["data"]["url"] })

        #try find user by fb email
        {:error, _} ->
           case Accounts.get_user_by_email(info["email"]) do
             {:ok, user} ->
                Accounts.update_user(user, %{facebook_id: info["id"], avatar: info["picture"]["data"]["url"] })
             {:error, _} ->
                Accounts.create_user(%{facebook_id: info["id"], email: info["email"], confirmed: true, name: info["name"], avatar: info["picture"]["data"]["url"]})
           end
      end

    else
      Accounts.create_user(%{facebook_id: info["id"], email: nil, name: info["name"], avatar: info["picture"]["data"]["url"]})
    end
  end


  def provisions(info, user, :google) when not is_nil(user) do
    #  {
      #   "sub": "116770861156797701714",
      #   "name": "Alexander Dmitriev",
      #   "given_name": "Alexander",
      #   "family_name": "Dmitriev",
      #   "profile": "https://plus.google.com/116770861156797701714",
      #   "picture": "https://lh4.googleusercontent.com/-rLStipVzPLw/AAAAAAAAAAI/AAAAAAAAAFg/xKzK4x2_YF8/photo.jpg",
      #   "email": "alexanderdmv@gmail.com",
      #   "email_verified": true,
      #   "gender": "male",
      #   "locale": "ru"
     #  }
    cond do
      user.google ->
        {:ok, user}
      user.email == info["email"] and info["email_verified"] ->
        Accounts.update_user(user, %{google: true, avatar: info["picture"], confirmed: true})
      true ->
        {:error, :email_not_maching_or_not_verified}
    end
  end

  def provisions(info, user, :google) when is_nil(user) do
    if not is_nil(info["email"]) and info["email_verified"] do
      case Accounts.get_user_by_email(info["email"]) do
        {:ok, user} ->
           Accounts.update_user(user, %{google: true, avatar: info["picture"], confirmed: true})
        {:error, _} ->
           Accounts.create_user(%{google: true, email: info["email"], name: info["name"], avatar: info["picture"], confirmed: true})
      end
    else
      {:error, :email_not_presents_or_not_verified, info}
    end
  end

  def disconnect(user, :facebook) do
    cond do
      user.google ->
        Accounts.update_user(user, %{facebook_id: nil})
      (not is_nil(user.email) and not is_nil(user.crypted_password) and user.by_email) ->
        Accounts.update_user(user, %{facebook_id: nil})
      true ->
        {:error, :cant_not_disconnect_facebook}
    end
  end


  def disconnect(user, :google) do
    cond do
      user.facebook_id ->
        Accounts.update_user(user, %{google: false})
      (not is_nil(user.email) and not is_nil(user.crypted_password) and user.by_email) ->
        Accounts.update_user(user, %{google: false})
      true ->
        {:error, :cant_not_disconnect_google}
    end
  end
end
