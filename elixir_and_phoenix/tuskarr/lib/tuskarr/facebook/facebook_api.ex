defmodule FacebookApi do
  alias Poison.Parser

  @facebook_server "https://graph.facebook.com/me"
  @fields "id,name,email,picture.width(320).height(320)"

  def get_info(key) do
    %HTTPotion.Response{body: body} = HTTPotion.get(@facebook_server, query: %{access_token: key, fields: @fields})
    response = body |> Parser.parse!

    case response["error"] do
      nil -> {:ok, response}
      _   -> {:error, :invalid_fb_token}
    end
  end
end
