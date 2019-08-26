defmodule Membrane.WebRTC.Server.Room do
  @moduledoc """
  Module containing functions for constructing rooms, adding or removing peers to them or sending and broadcasting messages between peers. 

  Room is `GenServer` prepared to send messages between peers by storing their IDs and PIDs.
  """

  use GenServer
  require Logger
  alias Membrane.WebRTC.Server.Message

  @typedoc """
  Defines custom state of Room, passed as argument and returned by callbacks. 
  """
  @type internal_state :: any

  @typedoc """
  Defines ID bound to PID when Peer joins the Room.
  """
  @type peer_id :: String.t()

  @typedoc """
  Defines options that can be passed to `start_link/1` and `c:on_init/1` callback.
  """
  @type room_options :: %{name: Registry.key(), module: module}

  defmodule State do
    @moduledoc false

    @enforce_keys [:module, :peers]
    defstruct [:internal_state] ++ @enforce_keys

    @type t :: %__MODULE__{
            peers: BiMap.t() | BiMap.new(),
            module: module(),
            internal_state: Membrane.WebRTC.Server.Room.internal_state()
          }
  end

  @doc """
  Callback invoked when room is created.
  Internally called in `init/1` callback.
  """
  @callback on_init(args :: room_options) :: {:ok, internal_state}

  @doc """
  Callback invoked before sending message.
  Room will send message returned by this callback, ergo returning `{:ok, state}` will cause ignoring message.
  Useful for modyfing or ignoring messages.
  """
  @callback on_message(
              message :: Message.t(),
              state :: internal_state()
            ) :: {:ok, internal_state()} | {:ok, Message.t(), internal_state()}

  @doc """
  Callback invoked before broadcasting message.
  Room will broadcast message returned by this callback, ergo returning `{:ok, state}` will cause ignoring message.
  Useful for modyfing or ignoring messages.
  """
  @callback on_broadcast(
              message :: Message.t(),
              broadcaster :: String.t() | nil,
              state :: internal_state()
            ) ::
              {:ok, internal_state()} | {:ok, Message.t(), internal_state()}

  @doc """
  Callback invoked when room is shutting down.
  Internally called in `c:GenServer.terminate/2` callback.
  Useful for any cleanup required.
  """
  @callback on_terminate(
              reason :: :normal | :shutdown | {:shutdown, any},
              state :: internal_state()
            ) :: :ok

  @doc """
  Starts Room based on given module, registers it in Server.Registry (under given name and value: `:room`) and links it to current process.

  Args are passed to module's `c:on_init/1` callback.
  """
  @spec start_link(args :: room_options) :: GenServer.on_start()
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

  @doc """
  Creates the room with given name and module under supervision of `Server.RoomSupervisor`. 
  """
  @spec create(room_name :: String.t(), module :: module()) :: DynamicSupervisor.on_start_child()
  def create(room_name, module) do
    child_spec = {Membrane.WebRTC.Server.Room, %{name: room_name, module: module}}
    Logger.info("Creating room #{room_name}")
    DynamicSupervisor.start_child(Server.RoomSupervisor, child_spec)
  end

  @doc """
  Adds the peer to the room. Broadcasts message (`%Message{event: joined, data: %{peer_id: peer_id}}`) to other peers in room. 
  """

  @spec join(room :: pid(), peer_id :: peer_id, peer_pid :: pid()) :: :ok
  def join(room, peer_id, peer_pid) do
    message = %Message{event: :joined, data: %{peer_id: peer_id}}
    broadcast(room, message)
    send(room, {:join, peer_id, peer_pid})
    :ok
  end

  @doc """
  Removes the peer from the room. Broadcast message (`%Message{event: left, data: %{peer_id: peer_id}}`) to other peers in room. 
  """
  @spec leave(room :: pid(), peer_id :: peer_id) :: :ok
  def leave(room, peer_id) do
    message = %Message{event: :left, data: %{peer_id: peer_id}}
    send(room, {:leave, peer_id})
    broadcast(room, message)
  end

  @doc """
  Sends the message to every peer in the room except for broadcaster.
  """
  @spec broadcast(
          room :: pid(),
          message :: Message.t(),
          broadcaster :: peer_id
        ) :: :ok
  def broadcast(room, message, broadcaster) do
    send(room, {:broadcast, message, broadcaster})
    :ok
  end

  @doc """
  Sends the message to every peer in the room.
  """
  @spec broadcast(room :: pid(), message :: Message.t()) :: :ok
  def broadcast(room, message) do
    send(room, {:broadcast, message})
    :ok
  end

  @doc """
  Sends the message to the peer given under `message.to` key.
  """
  @spec send_message(room :: pid(), message :: Message.t()) ::
          :ok | {:error, :no_such_peer} | {:error, :unknown_error}
  def send_message(room, %Message{to: peer_id} = message) when peer_id != nil do
    case GenServer.call(room, {:send, message}) do
      :ok ->
        :ok

      {:error, :no_such_peer} ->
        Logger.error("Could not find peer")
        {:error, :no_such_peer}

      _ ->
        Logger.error("Unknown error")
        {:error, :unknown_error}
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
        case state.peers[message.to] do
          nil ->
            {:reply, {:error, :no_such_peer}, %State{state | internal_state: internal_state}}

          pid ->
            send(pid, message)
            {:reply, :ok, %State{state | internal_state: internal_state}}
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
