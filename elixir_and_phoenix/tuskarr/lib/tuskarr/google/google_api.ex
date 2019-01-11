defmodule GoogleApi do
  alias Poison.Parser

  @goole_server "https://www.googleapis.com/oauth2/v3/userinfo"

  def get_info(key) do
    %HTTPotion.Response{body: body} = HTTPotion.get(@goole_server, query: %{access_token: key})
    response = body |> Parser.parse!

    case response["error"] do
      nil -> {:ok, response}
      _   -> {:error, :invalid_google_token}
    end
  end
end
