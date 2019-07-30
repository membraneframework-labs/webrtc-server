defmodule Membrane.WebRTC.Server.Room do
  use GenServer
  require Logger

  defmodule State do
    @enforce_keys [:peers]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            peers: map()
          }
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(%{name: name}) do
    Registry.register(Server.Registry, :room, name)
    state = %State{peers: %{}}
    {:ok, state}
  end

  @impl true
  def handle_call({:send, message, peer_id}, _from, state) do
    pid = state.peers[peer_id]

    if pid != nil do
      send(pid, message)
      {:reply, :ok, state}
    else
      {:reply, {:error, :no_such_peer}, state}
    end
  end

  @impl true
  def handle_info({:join, peer_id, pid}, state) when is_pid(pid) do
    state = Map.put(state, :peers, Map.put(state.peers, peer_id, pid))
    {:noreply, state}
  end

  @impl true
  def handle_info({:leave, peer_id}, state) do
    state = Map.put(state, :peers, Map.drop(state.peers, [peer_id]))

    if state == %State{peers: %{}} do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:broadcast, message}, state) do
    Enum.each(state.peers, fn {_peer, pid} -> send(pid, message) end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:broadcast, message, broadcaster}, state) do
    Enum.each(state.peers, fn {peer_id, pid} ->
      if peer_id != broadcaster do
        send(pid, message)
      end
    end)

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %State{peers: peers}) when map_size(peers) == 0,
    do: :ok

  @impl true
  def terminate(_reason, state) do
    {:ok, message} = Jason.encode(%{"event" => :room_closed})
    Enum.each(state.peers, fn {_, pid} -> send(pid, {:text, message}) end)
    :ok
  end

  def create(room_name) do
    child_spec = {Membrane.WebRTC.Server.Room, %{name: room_name}}
    Logger.info("Creating room #{room_name}")
    DynamicSupervisor.start_child(Membrane.WebRTC.Server, child_spec)
  end

  def join(pid, peer_id, peer_pid) do
    {:ok, message} = Jason.encode(%{"event" => :joined, "data" => %{peer_id: peer_id}})

    broadcast(pid, {:text, message})
    send(pid, {:join, peer_id, peer_pid})
  end

  def leave(pid, peer_id) do
    {:ok, message} = Jason.encode(%{"event" => :left, "data" => %{"peer_id" => peer_id}})

    send(pid, {:leave, peer_id})
    broadcast(pid, {:text, message})
  end

  def broadcast(pid, message, broadcaster),
    do: send(pid, {:broadcast, message, broadcaster})

  def broadcast(pid, message),
    do: send(pid, {:broadcast, message})

  def send_message(pid, message, to, from) do
    {:ok, message} = Map.put(message, "from", from) |> Jason.encode()

    case GenServer.call(pid, {:send, {:text, message}, to}) do
      :ok ->
        :ok

      {:error, :no_such_peer} ->
        Logger.error("Could not find peer")
        {:error, :no_such_peer}

      _ ->
        Logger.error("Unknown error")
        {:error, :unknown}
    end
  end
end
