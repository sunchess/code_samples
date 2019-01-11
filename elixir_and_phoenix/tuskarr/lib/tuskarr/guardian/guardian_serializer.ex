defmodule Tuskarr.GuardianSerializer do
  @behaviour Guardian.Serializer

  alias Tuskarr.Repo
  alias Tuskarr.Accounts.User

  import Ecto.Query, warn: false

  def for_token(user = %User{}), do: { :ok, "User:#{user.id}" }
  def for_token(_), do: { :error, "Unknown resource type" }

  def from_token("User:" <> id), do: { :ok, User |> where(id: ^id, disabled: false ) |> Repo.one }
  def from_token(_), do: { :error, "Unknown resource type" }
end
