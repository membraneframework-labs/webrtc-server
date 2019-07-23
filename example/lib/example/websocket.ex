defmodule Example.WebSocket do
  use Membrane.WebRTC.Server.WebSocket

  @impl true
  def authenticate(request, _args) do
    room = :cowboy_req.binding(:room, request)
    {:ok, room: room}
  end

  @impl true
  def on_websocket_init(state) do
    {:ok, encoded} =
      Jason.encode(%{"event" => :authenticated, "data" => %{"peer_id" => state.peer_id}})

    {:reply, {:text, encoded}}
  end
end
