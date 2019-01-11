defmodule TuskarrWeb.PasswordView do
  use TuskarrWeb, :view
  alias TuskarrWeb.UserView

  def render("user.json", %{user: user}) do
    render_one(user, UserView, "user.json")
  end

end
