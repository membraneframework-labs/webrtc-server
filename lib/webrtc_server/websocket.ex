defmodule Membrane.WebRTC.Server.WebSocket do
  @behaviour :cowboy_websocket
  require Logger
  require Jason

  defmodule State do
    defstruct [:room, :username, :peer_id]

    @type t :: %__MODULE__{
            room: String.t() | nil,
            username: String.t() | nil,
            peer_id: String.t() | nil
          }
  end

  def init(request, _state) do
    state = %State{}
    opts = %{idle_timeout: 1000 * 60 * 15}
    {:cowboy_websocket, request, state, opts}
  end

  def websocket_init(state) do
    {:ok, state}
  end

  def websocket_handle({:text, "ping"}, state) do
    {:reply, {:text, "pong"}, state}
  end

  def websocket_handle({:text, text}, state),
    do: text |> Jason.decode() |> handle_message(state)

  def websocket_handle(_, state) do
    Logger.warn("Non-text frame")
    {:ok, state}
  end

  def websocket_info(message, state) do
    {:reply, message, state}
  end

  def terminate(_reason, _partial_req, %State{room: room, peer_id: peer_id, username: username}) do
    Logger.debug("Terminating peer #{peer_id}")
    [{room_pid, ^room}] = Registry.match(Server.Registry, :room, room)

    {:ok, message} =
      Jason.encode(%{"event" => :left, "data" => %{"peer_id" => peer_id, "username" => username}})

    GenServer.cast(room_pid, {:remove, peer_id})
    GenServer.cast(room_pid, {:broadcast, {:text, message}})
    :ok
  end

  defp handle_message(
         {:ok,
          %{
            "event" => "authenticate",
            "data" => %{"username" => username, "room" => room}
          }},
         state
       ) do
    "#Reference" <> peer_id = Kernel.inspect(Kernel.make_ref())
    Logger.debug("Registering #{Kernel.inspect(self())} to peer number #{peer_id}")
    join_room(room, username, peer_id)

    state =
      Map.put(state, :peer_id, peer_id) |> Map.put(:username, username) |> Map.put(:room, room)

    {:ok, encoded} = Jason.encode(%{"event" => :authenticated, "data" => %{"peer_id" => peer_id}})
    {:reply, {:text, encoded}, state}
  end

  defp handle_message(
         {:ok, %{"to" => peer_id, "data" => _} = message},
         %State{peer_id: my_peer_id, room: room} = state
       ) do
    Logger.debug("Sending message to peer: #{peer_id} from: #{my_peer_id} in room: #{room}")

    {:ok, message} = Map.put(message, "from", my_peer_id) |> Jason.encode()
    [{room_pid, ^room}] = Registry.match(Server.Registry, :room, room)

    if GenServer.call(room_pid, {:send, {:text, message}, peer_id}) != :ok do
      Logger.error("Could not find peer")
    end

    {:ok, state}
  end

  defp handle_message({:error, _}, state) do
    Logger.error("Wrong message")
    {:ok, encoded} = Jason.encode(%{"event" => :error, "description" => "invalid json"})
    {:reply, {:text, encoded}, state}
  end

  defp join_room(room, username, peer_id) do
    if(Registry.match(Server.Registry, :room, room) == []) do
      children = [Membrane.WebRTC.Server.Room.child_spec(name: room)]
      opts = [strategy: :one_for_one, name: __MODULE__]
      {:ok, _} = Supervisor.start_link(children, opts)
    end

    [{room_pid, ^room}] = Registry.match(Server.Registry, :room, room)

    {:ok, message} =
      Jason.encode(%{"event" => :joined, "data" => %{peer_id: peer_id, username: username}})

    GenServer.cast(room_pid, {:broadcast, {:text, message}})
    GenServer.cast(room_pid, {:add, peer_id, self()})
  end
end
