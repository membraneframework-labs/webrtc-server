defmodule Membrane.WebRTC.Server.WebSocket do
  @behaviour :cowboy_websocket
  require Logger
  require Jason

  defmodule State do
    defstruct [:room, :username, :peer_id]

    @type t :: %__MODULE__{
            room: string() | nil,
            username: string() | nil,
            peer_id: integer()
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

  def websocket_handle(message, state) do
    Logger.warn("Non-text frame")
    {:ok, state}
  end

  def websocket_info(message, state) do
    {:reply, message, state}
  end

  def terminate(_reason, _partial_req, %State{room: room, peer_id: peer_id, username: username}) do
    Logger.debug("Terminating peer #{peer_id}")
    broadcast_to_room(room, :left, %{peer_id: peer_id, username: username}, peer_id)
    :ok
  end

  defp handle_message(
         {:ok,
          %{
            "event" => "authenticate",
            "data" => %{"username" => username, "password" => password, "room" => room}
          }},
         state
       ) do
    peer_id = :rand.uniform(1_000_000)

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

    case Registry.match(Registry.Server, room, peer_id) do
      [{pid, _}] ->
        send(pid, {:text, message})
        {:ok, state}

      _ ->
        Logger.error("Could not find pid")
        {:ok, state}
    end
  end

  defp handle_message({:error, _}, state) do
    Logger.error("Wrong message")
    {:ok, encoded} = Jason.encode(%{"event" => :error, "description" => "invalid json"})
    {:reply, {:text, encoded}, state}
  end

  defp join_room(room, username, peer_id) do
    {:ok, owner} = Registry.register(Registry.Server, room, peer_id)
    broadcast_to_room(room, :joined, %{peer_id: peer_id, username: username}, peer_id)
  end

  defp broadcast_to_room(room, event, data, self_peer) do
    {:ok, encoded} = Jason.encode(%{"event" => event, "data" => data})

    Registry.dispatch(Registry.Server, room, fn entries ->
      Enum.each(entries, fn {pid, peer} ->
        if peer != self_peer do
          send(pid, {:text, encoded})
        end
      end)
    end)
  end
end
