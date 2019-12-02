defmodule Example.Auth.Peer do
  @moduledoc false
  @token_cookie "guardian_default_token"

  use Membrane.WebRTC.Server.Peer
  require Logger

  @impl true
  def parse_request(request) do
    case :cowboy_req.parse_cookies(request) |> List.keyfind(@token_cookie, 0) do
      {@token_cookie, token} ->
        {:ok, %{token: token}, nil, "room"}

      _ ->
        {:error, :no_token_passed}
    end
  end

  @impl true
  def on_receive(message, context, state) do
    Logger.info("Sending message to peers #{inspect(message.to)} from #{context.peer_id}")

    {:ok, message, state}
  end
end
