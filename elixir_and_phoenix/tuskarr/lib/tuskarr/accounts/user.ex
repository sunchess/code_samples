defmodule Tuskarr.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Tuskarr.Accounts.User


  schema "users" do
    field :avatar, :string
    field :email, :string
    field :crypted_password, :string
    field :password, :string, virtual: true
    field :facebook_id, :string
    field :google, :boolean, default: false
    field :name, :string
    field :pro, :boolean, default: false
    field :recovery_password_token, :string
    field :by_email, :boolean, default: false
    field :confirmation_token, :string
    field :confirmed, :boolean, default: false
    field :disabled, :boolean, default: false

    timestamps()
  end

  @doc false
  def changeset(%User{} = user, %{"by_email" => true} = attrs) do
    user
    |> cast(attrs, [:email, :name, :pro, :avatar, :password, :recovery_password_token, :by_email, :confirmation_token, :confirmed, :disabled])
    |> validate_required([:email, :name, :password])
    |> unique_constraint(:email)
    |> validate_format(:email, ~r/@/)
    |> hashed_password
  end

  @doc """
  Only socials
  """
  def changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:email, :name, :pro, :avatar, :facebook_id, :google, :password, :recovery_password_token, :confirmation_token, :confirmed, :disabled])
    |> validate_required([:name])
    |> email_prepare
  end

  def email_changeset(%User{} = user, %{"email" => _email} = attrs) do
    user
    |> cast(attrs, [:email])
    |> unique_constraint(:email)
  end

  def password_changeset(%User{} = user, %{"password" => _password} = attrs) do
    user
    |> cast(attrs, [:password, :by_email])
    |> hashed_password
  end



  defp hashed_password(user) do
    password = get_field(user, :password)
    user = if password do
      user |> put_change(:crypted_password, Comeonin.Bcrypt.hashpwsalt(password))
    else
      user
    end

    IO.inspect(user)
    user
  end

  defp email_prepare(user) do
    email = get_field(user, :email)
    user = if email do
      user
      |> put_change(:confirmed, true)
      |> unique_constraint(:email)
      |> validate_format(:email, ~r/@/)
    else
      user
    end

    user
  end
end
