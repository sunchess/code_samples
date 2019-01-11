defmodule TuskarrWeb.SessionView do
  use TuskarrWeb, :view
  alias TuskarrWeb.UserView

  def render("user.json", %{user: user, jwt: jwt}) do
    %{auth_token: jwt, account: render_one(user, UserView, "user.json")}
  end

end
