defmodule Example.Peer do
  use Membrane.WebRTC.Server.Peer

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

    IO.puts("Hello there, I'm #{state.username}")
    IO.puts("This is my spec: #{inspect(state.spec)}")
    {:reply, {:text, encoded}, state}
  end
end
