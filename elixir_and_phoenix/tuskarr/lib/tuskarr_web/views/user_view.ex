defmodule TuskarrWeb.UserView do
  use TuskarrWeb, :view
  alias TuskarrWeb.UserView

  # def render("index.json", %{users: users}) do
  #   %{data: render_many(users, UserView, "user.json")}
  # end

  def render("show.json", %{user: user, jwt: jwt}) do
    %{auth_token: jwt, account: render_one(user, UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{account: render_one(user, UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{id: user.id,
      email: user.email,
      name: user.name,
      pro: user.pro,
      avatar: user.avatar,
      facebook_id: user.facebook_id,
      google: user.google,
      confirmed: user.confirmed,
      by_email: user.by_email
    }
  end
end
