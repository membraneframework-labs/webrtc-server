defmodule Membrane.WebRTC.Server.Room do
  use GenServer
  require Jason

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
  def handle_call({:send, message, peer}, _, state) do
    pid = state.peers[peer]

    if pid != nil do
      send(pid, message)
      {:reply, :ok, state}
    else
      {:reply, {:error, "no such peer"}, state}
    end
  end

  @impl true
  def handle_cast({:add, peer, pid}, state) do
    state = Map.put(state, :peers, Map.put(state.peers, peer, pid))
    {:noreply, state}
  end

  def handle_cast({:remove, peer}, state) do
    state = Map.put(state, :peers, Map.drop(state.peers, [peer]))

    if state == %State{peers: %{}} do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:broadcast, message}, state) do
    Enum.each(state.peers, fn {_, pid} -> send(pid, message) end)
    {:noreply, state}
  end

  def handle_cast({:broadcast, message, broadcaster}, state) do
    Enum.each(state.peers, fn {peer, pid} ->
      if peer != broadcaster do
        send(pid, message)
      end
    end)

    {:noreply, state}
  end

  @impl true
  def terminate(_, %State{peers: peers}) when map_size(peers) == 0,
    do: :ok

  def terminate(reason, state) do
    {:ok, message} = Jason.encode(%{"event" => :room_closed})
    Enum.each(state.peers, fn {_, pid} -> send(pid, {:text, message}) end)
    :ok
  end
end
