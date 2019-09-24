defmodule Membrane.WebRTC.Server.Room do
  @moduledoc """
  Module containing functions for constructing rooms, adding or removing peers to them
  or sending and broadcasting messages between peers. 

  Room is `GenServer` prepared to send messages between peers by storing their IDs and PIDs.
  """

  use GenServer
  require Logger
  alias Membrane.WebRTC.Server.{Message, Peer}
  alias Membrane.WebRTC.Server.Peer.AuthData

  @typedoc """
  Defines custom state of Room, passed as argument and returned by callbacks. 
  """
  @type internal_state :: any

  @typedoc """
  Defines ID bound to PID when Peer joins the Room.
  """
  @type peer_id :: String.t()

  @typedoc """
  Defines options that can be passed to `c:start_link/1` and `c:on_init/1` callback.
  """
  @type room_options :: %{name: Registry.key(), module: module}

  defmodule State do
    @moduledoc false

    @enforce_keys [:module, :peers]
    defstruct [:internal_state] ++ @enforce_keys

    @type t :: %__MODULE__{
            peers: BiMap.t() | %BiMap{},
            module: module(),
            internal_state: Membrane.WebRTC.Server.Room.internal_state()
          }
  end

  @doc """
  Callback invoked when room is created.

  This callback is optional.
  """
  @callback on_init(args :: room_options) :: {:ok, internal_state()}

  @doc """
  Callback invoked when peer is about to join the room.

  Usefull for authorizing or performing other checks (i.e. controling number of peers in room).

  Returning `{:error, error}` will cause Peer sending message
  ```
  {
    "event": "error",
    "data": {
        "description": "Could not join room",
        "details": error
    }
  }
  ``` 
  to client and closing WebSocket.

  This callback is optional.
  """
  @callback on_join(auth_data :: AuthData.t(), state :: internal_state()) ::
              {:ok, internal_state()} | {{:error, error :: atom()}, internal_state()}

  @doc """
  Callback invoked when peer is leaving the room.

  This callback is optional.
  """
  @callback on_leave(peer_id :: String.t(), state :: internal_state()) ::
              {:ok, internal_state()}

  @doc """
  Callback invoked before sending message.
  Room will send message returned by this callback, ergo returning `{:ok, state}`
  will cause ignoring message.

  This callback is optional.
  """
  @callback on_send(
              message :: Message.t(),
              state :: internal_state()
            ) :: {:ok, internal_state()} | {:ok, Message.t(), internal_state()}

  @doc """
  Callback invoked before broadcasting message.
  Room will broadcast message returned by this callback, ergo returning `{:ok, state}`
  will cause ignoring message.

  This callback is optional.
  """
  @callback on_broadcast(
              message :: Message.t(),
              broadcaster :: String.t() | nil,
              state :: internal_state()
            ) ::
              {:ok, internal_state()} | {:ok, Message.t(), internal_state()}

  @doc """
  Callback invoked when room is shutting down.
  Useful for any cleanup required.

  This callback is optional.
  """
  @callback on_terminate(state :: internal_state()) :: :ok

  @doc """
  Starts Room based on given module, registers itself in Server.Registry
  (under given name) and links it to current process.

  Args are passed to module's `c:on_init/1` callback.
  """
  @spec start_link(args :: room_options) :: GenServer.on_start()
  def start_link(%{name: room_name} = args) do
    name = {:via, Registry, {Server.Registry, room_name}}
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc """
  Creates the room with given name and module under supervision of `Membrane.WebRTC.Server.RoomSupervisor`. 
  """
  @spec create(room_name :: String.t(), module :: module()) :: DynamicSupervisor.on_start_child()
  def create(room_name, module) do
    child_spec = {Membrane.WebRTC.Server.Room, %{name: room_name, module: module}}
    DynamicSupervisor.start_child(Server.RoomSupervisor, child_spec)
  end

  @doc """
  Adds the peer to the room. Broadcasts message
  (`%Message{event: joined, data: %{peer_id: peer_id}}`) to other peers in room. 
  """
  @spec join(room :: pid(), auth_data :: AuthData.t(), peer_pid :: pid()) ::
          :ok | {:error, atom()} | {:error, {atom(), any()}}
  def join(room, auth_data, peer_pid) do
    with :ok <-
           GenServer.call(
             room,
             {:join, auth_data, peer_pid}
           ) do
      message = %Message{event: "joined", data: %{peer_id: auth_data.peer_id}}
      broadcast(room, message, auth_data.peer_id)
      :ok
    end
  end

  @doc """
  Removes the peer from the room. Broadcast message 
  (`%Message{event: left, data: %{peer_id: peer_id}}`) to other peers
  if given peer was in the room. 
  """
  @spec leave(room :: pid(), peer_id :: peer_id) :: :ok
  def leave(room, peer_id) do
    GenServer.cast(room, {:leave, peer_id})
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
    GenServer.cast(room, {:broadcast, message, broadcaster})
    :ok
  end

  @doc """
  Sends the message to every peer in the room.
  """
  @spec broadcast(room :: pid(), message :: Message.t()) :: :ok
  def broadcast(room, message) do
    GenServer.cast(room, {:broadcast, message})
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

  @doc """
  Stops room process.
  """
  @spec stop(room :: pid()) :: :ok
  def stop(room) do
    GenServer.cast(room, :stop)
  end

  @impl true
  def init(%{module: module} = args) do
    state = %State{peers: BiMap.new(), module: module}
    callback_exec(:on_init, [args], state)
  end

  @impl true
  def handle_call({:send, message}, _from, state),
    do: callback_exec(:on_send, [message], state)

  @impl true
  def handle_call({:join, auth_data, peer_pid}, _from, state) do
    case callback_exec(:on_join, [auth_data], state) do
      {:ok, state} ->
        peers = state.peers |> BiMap.put(auth_data.peer_id, peer_pid)
        state = %State{state | peers: peers}

        Process.monitor(peer_pid)
        {:reply, :ok, state}

      {{:error, error}, state} ->
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_cast({:leave, peer_id}, state) do
    if BiMap.has_key?(state.peers, peer_id) do
      {:ok, internal_state} = callback_exec(:on_leave, [peer_id], state)
      peers = BiMap.delete_key(state.peers, peer_id)

      new_state =
        state
        |> Map.put(:peers, peers)
        |> Map.put(:internal_state, internal_state)

      message = %Message{event: "left", data: %{peer_id: peer_id}}
      broadcast(self(), message)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:broadcast, message}, state),
    do: callback_exec(:on_broadcast, [message, nil], state)

  @impl true
  def handle_cast({:broadcast, message, broadcaster}, state),
    do: callback_exec(:on_broadcast, [message, broadcaster], state)

  @impl true
  def handle_cast(:stop, state),
    do: {:stop, :normal, state}

  @impl true
  def handle_info({:DOWN, _reference, :process, pid, _reason}, state) do
    peer_id = BiMap.get_key(state.peers, pid)
    leave(self(), peer_id)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    callback_exec(:on_terminate, [], state)
  end

  defp callback_exec(:on_init, args, state) do
    {:ok, internal_state} = apply(state.module, :on_init, args)
    {:ok, %State{state | internal_state: internal_state}}
  end

  defp callback_exec(:on_join, args, state) do
    case apply(state.module, :on_join, args ++ [state.internal_state]) do
      {:ok, internal_state} ->
        state = %State{state | internal_state: internal_state}
        {:ok, state}

      {{:error, error}, internal_state} ->
        state = %State{state | internal_state: internal_state}
        {{:error, error}, state}
    end
  end

  defp callback_exec(:on_leave, args, state),
    do: apply(state.module, :on_leave, args ++ [state.internal_state])

  defp callback_exec(:on_broadcast, [_msg, broadcaster] = args, state) do
    case apply(state.module, :on_broadcast, args ++ [state.internal_state]) do
      {:ok, internal_state} ->
        {:noreply, %State{state | internal_state: internal_state}}

      {:ok, message, internal_state} ->
        if broadcaster == nil do
          Enum.each(state.peers, fn {_peer, pid} ->
            Peer.send_to_client(pid, message)
          end)
        else
          Enum.each(state.peers, fn {peer_id, pid} ->
            if peer_id != broadcaster do
              Peer.send_to_client(pid, message)
            end
          end)
        end

        {:noreply, %State{state | internal_state: internal_state}}
    end
  end

  defp callback_exec(:on_send, args, state) do
    case apply(state.module, :on_send, args ++ [state.internal_state]) do
      {:ok, internal_state} ->
        {:noreply, %State{state | internal_state: internal_state}}

      {:ok, message, internal_state} ->
        case state.peers[message.to] do
          nil ->
            {:reply, {:error, :no_such_peer}, %State{state | internal_state: internal_state}}

          pid ->
            Peer.send_to_client(pid, message)
            {:reply, :ok, %State{state | internal_state: internal_state}}
        end
    end
  end

  defp callback_exec(:on_terminate, args, state),
    do: apply(state.module, :on_terminate, args ++ [state.internal_state])

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)

      def on_init(_args),
        do: {:ok, %{}}

      def on_join(_auth_data, state),
        do: {:ok, state}

      def on_leave(_peer_id, state),
        do: {:ok, state}

      def on_send(message, state) do
        {:ok, message, state}
      end

      def on_broadcast(message, _from, state) do
        {:ok, message, state}
      end

      def on_terminate(_state),
        do: :ok

      defoverridable on_init: 1,
                     on_join: 2,
                     on_leave: 2,
                     on_send: 2,
                     on_broadcast: 3,
                     on_terminate: 1
    end
  end
end
