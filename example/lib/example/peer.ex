defmodule Example.Peer do
  use Membrane.WebRTC.Server.Peer
  require Logger

  @impl true
  def authenticate(request, spec) do
    room = :cowboy_req.binding(:room, request)
    state = %{username: "user_#{Integer.to_string(:rand.uniform(1_000_000))}", spec: spec}
    {:ok, %{room: room, state: state}}
  end

  @impl true
  def on_websocket_init(context, state) do
    {:ok, encoded} =
      Jason.encode(%{"event" => :authenticated, "data" => %{"peer_id" => context.peer_id}})

    Logger.info("Hello there, I'm #{state.username}")
    Logger.info("This is my spec: #{inspect(state.spec)}")
    {:reply, {:text, encoded}, state}
  end

  @impl true
  def on_message(message, context, state) do
    Logger.info(
      "Sending message to peer #{Map.get(message, "to")} from #{context.peer_id} in room #{
        context.room
      }"
    )

    {:ok, message, state}
  end
end
