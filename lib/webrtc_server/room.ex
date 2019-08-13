defmodule Membrane.WebRTC.Server.Room do
  use GenServer
  require Logger
  alias Membrane.WebRTC.Server.Message

  @type internal_state :: any

  defmodule State do
    @enforce_keys [:peers]
    defstruct [:module, :internal_state] ++ @enforce_keys

    @type t :: %__MODULE__{
            peers: BiMap.t(),
            module: module(),
            internal_state: Membrane.WebRTC.Server.Peer.Context.internal_state()
          }
  end

  @callback on_init(args :: map) :: {:ok, internal_state}

  @callback on_message(
              message :: Message.t(),
              state :: internal_state()
            ) :: {:ok, internal_state()} | {:ok, Message.t(), internal_state()}

  @callback on_broadcast(
              message :: Message.t(),
              broadcaster :: String.t() | nil,
              state :: internal_state()
            ) ::
              {:ok, internal_state()} | {:ok, Message.t(), internal_state()}

  @callback on_terminate(
              reason :: :normal | :shutdown | {:shutdown, any},
              state :: internal_state()
            ) :: :ok

  def start_link(%{name: room_name} = args) do
    name = {:via, Registry, {Server.Registry, room_name, :room}}
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @impl true
  def init(%{module: module} = args) do
    state = %State{peers: BiMap.new(), module: module}
    callback_exec(:on_init, [args], state)
  end

  @impl true
  def handle_call({:send, message}, _from, state),
    do: callback_exec(:on_message, [message], state)

  @impl true
  def handle_info({:join, peer_id, pid}, state) when is_pid(pid) do
    Process.monitor(pid)
    state = %State{state | peers: BiMap.put(state.peers, peer_id, pid)}
    {:noreply, state}
  end

  @impl true
  def handle_info({:leave, peer_id}, state) do
    state = %State{state | peers: BiMap.delete_key(state.peers, peer_id)}

    if BiMap.size(state.peers) == 0 do
      DynamicSupervisor.terminate_child(Server.RoomSupervisor, self())
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:broadcast, message}, state),
    do: callback_exec(:on_broadcast, [message, nil], state)

  @impl true
  def handle_info({:broadcast, message, broadcaster}, state),
    do: callback_exec(:on_broadcast, [message, broadcaster], state)

  @impl true
  def handle_info({:DOWN, _reference, :process, pid, _reason}, state) do
    peer_id = BiMap.get_key(state.peers, pid)
    leave(self(), peer_id)
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    callback_exec(:on_terminate, [reason], state)
  end

  def create(room_name, module) do
    child_spec = {Membrane.WebRTC.Server.Room, %{name: room_name, module: module}}
    Logger.info("Creating room #{room_name}")
    DynamicSupervisor.start_child(Server.RoomSupervisor, child_spec)
  end

  def join(pid, peer_id, peer_pid) do
    message = %Message{event: :joined, data: %{peer_id: peer_id}}
    broadcast(pid, message)
    send(pid, {:join, peer_id, peer_pid})
  end

  def leave(pid, peer_id) do
    message = %Message{event: :left, data: %{peer_id: peer_id}}
    send(pid, {:leave, peer_id})
    broadcast(pid, message)
  end

  def broadcast(pid, message, broadcaster),
    do: send(pid, {:broadcast, message, broadcaster})

  def broadcast(pid, message),
    do: send(pid, {:broadcast, message})

  def send_message(pid, %Message{} = message) do
    case GenServer.call(pid, {:send, message}) do
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

  defp callback_exec(:on_init, args, state) do
    {:ok, internal_state} = apply(state.module, :on_init, args)
    {:ok, %State{state | internal_state: internal_state}}
  end

  defp callback_exec(:on_message, args, state) do
    case apply(state.module, :on_message, args ++ [state.internal_state]) do
      {:ok, internal_state} ->
        {:noreply, %State{state | internal_state: internal_state}}

      {:ok, message, internal_state} ->
        pid = state.peers[message.to]

        if pid != nil do
          send(pid, message)
          {:reply, :ok, %State{state | internal_state: internal_state}}
        else
          {:reply, {:error, :no_such_peer}, %State{state | internal_state: internal_state}}
        end
    end
  end

  defp callback_exec(:on_broadcast, [_msg, broadcaster] = args, state) do
    case apply(state.module, :on_broadcast, args ++ [state.internal_state]) do
      {:ok, internal_state} ->
        {:noreply, %State{state | internal_state: internal_state}}

      {:ok, message, internal_state} ->
        if broadcaster == nil do
          Enum.each(state.peers, fn {_peer, pid} -> send(pid, message) end)
        else
          Enum.each(state.peers, fn {peer_id, pid} ->
            if peer_id != broadcaster do
              send(pid, message)
            end
          end)
        end

        {:noreply, %State{state | internal_state: internal_state}}
    end
  end

  defp callback_exec(:on_terminate, args, state),
    do: apply(state.module, :on_terminate, args ++ [state.internal_state])

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)

      def on_init(_args),
        do: {:ok, %{}}

      def on_message(message, state) do
        {:ok, message, state}
      end

      def on_broadcast(message, _from, state) do
        {:ok, message, state}
      end

      def on_terminate(_reason, _state),
        do: :ok

      defoverridable on_init: 1,
                     on_message: 2,
                     on_broadcast: 3,
                     on_terminate: 2
    end
  end
end
