defmodule Example.Peer do
  @moduledoc false

  use Membrane.WebRTC.Server.Peer
  require Logger

  @impl true
  def parse_request(request) do
    room = :cowboy_req.binding(:room, request)

    if room == :undefined do
      {:error, :no_room_bound_in_url}
    else
      username = :cowboy_req.binding(:username, request, "")
      password = :cowboy_req.binding(:password, request, "")
      credentials = %{username: username, password: password}
      {:ok, credentials, nil, room}
    end
  end

  @impl true
  def on_init(_context, auth_data, _options) do
    username = auth_data.credentials.username
    password = auth_data.credentials.password

    if username != "" and password != "" do
      state = %{username: username}
      {:ok, state}
    else
      {:error, :empty_credentials}
    end
  end

  @impl true
  def on_receive(message, context, state) do
    Logger.info("Sending message to peers #{inspect(message.to)} from #{context.peer_id}")

    {:ok, message, state}
  end
end
