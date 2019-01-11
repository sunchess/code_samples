defmodule Tuskarr.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Tuskarr.Repo
  alias Tuskarr.Accounts.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """

  def create_user(%{"by_email" => true} = attrs ) do
    attrs = attrs |> Map.put("confirmation_token", UUID.uuid4(:hex))
    result = %User{} |> User.changeset(attrs) |> Repo.insert()

    case result do
      {:ok, user} ->
        case Tuskarr.Mailer.welcome_email(user) do
          {:ok, _}                 -> IO.inspect("Sending mail to #{user.name} saccessfully")
          {:error, _code, message} -> IO.inspect("Seinding mail error #{message}")
        end

        result
      _ ->
        result
    end
  end

  @doc """
    From socials user create
  """

  def create_user(attrs) do
    %User{} |> User.changeset(attrs) |> Repo.insert()
  end


  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  @doc """
    Update only email of user
  """
  def update_email(%User{} = user, attrs) do
    result = user |> User.email_changeset(Map.put(attrs, "confirmed", false)) |> Repo.update()

    case result do
      {:ok, user} ->
        case Tuskarr.Mailer.confirm_email(user) do
          {:ok, _}                 -> IO.inspect("Sending confirmation email to #{user.name} saccessfully")
          {:error, _code, message} -> IO.inspect("Seinding email error #{message}")
        end

        result
      _ ->
        result
    end
  end

  @doc """
    Update only password of user
  """
  def update_password(%User{} = user, attrs) do
    user
      |> User.password_changeset(attrs)
      |> Repo.update()
  end


  @doc """
    Set email and password
  """
  def connect_email(%User{} = user, attrs) do
    if user.by_email do
      {:error, :user_has_email_connection}
    else
      attrs = attrs |> Map.put("by_email", true)
      result = user |> User.changeset(attrs) |> Repo.update()

      case result do
        {:ok, user} ->
          #TODO: check user email if different between new email and seved email
          case Tuskarr.Mailer.confirm_email(user) do
            {:ok, _}                 -> IO.inspect("Sending confirmation email to #{user.name} saccessfully")
            {:error, _code, message} -> IO.inspect("Seinding email error #{message}")
          end

          result
        _ ->
          result
      end
    end
  end



  def get_user_by_email(email) do
    user = User |> where(email: ^email) |> Repo.one

    case user do
      %User{} -> {:ok, user}
      nil -> {:error, :email_not_found}
    end
  end

  def get_confirmed_user_by_email(email) do
    user = User |> where(email: ^email, confirmed: true) |> Repo.one

    case user do
      %User{} -> {:ok, user}
      nil -> {:error, :email_not_found_or_user_not_confirmed}
    end
  end

  def get_user_by_fb_id(token) do
    user = User |> where(facebook_id: ^token) |> Repo.one

    case user do
      %User{} -> {:ok, user}
      nil -> {:error, :token_not_found}
    end
  end

  def get_user_by_token(token) do
    user = User |> where(recovery_password_token: ^token) |> Repo.one

    case user do
      %User{} -> {:ok, user}
      nil -> {:error, :token_not_found}
    end
  end


  def get_user_by_confirm_token(token) do
    user = User |> where(confirmation_token: ^token) |> Repo.one

    case user do
      %User{} -> {:ok, user}
      nil -> {:error, :token_not_found}
    end
  end


  def disable(user) do
    update_user(user, %{disabled: true})
  end
end
