defmodule Membrane.WebRTC.Server.Room do
  @moduledoc """
  A behaviuor module for WebRTC room that manages peers and mediate in their communication.

  Rooms have to be created explicitly (preferably by `start_supervised/2` function).  
  """

  use GenServer
  require Logger
  alias Membrane.WebRTC.Server.{Message, Peer, RoomSupervisor}
  alias Membrane.WebRTC.Server.Peer.AuthData
  alias Membrane.WebRTC.Server.Room.{DefaultRoom, State}

  @typedoc """
  Defines a custom state of the room, passed as argument and returned by callbacks. 
  """
  @type internal_state :: any()

  @typedoc """
  Defines options that can be passed to `c:start_link/1` and `c:on_init/1` callback.
  """
  @type room_options :: %{name: Registry.key(), module: module() | nil}

  @doc """
  Callback invoked when a room is created.
  """
  @callback on_init(args :: room_options) :: {:ok, internal_state()}

  @doc """
  Callback invoked when a peer is about to join the room.

  Useful for authorizing or performing other checks (e.g. controlling number of peers in room).

  Returning `{:error, error}` will cause peer sending 
  `t:Membrane.WebRTC.Server.Message.error_message/0` to the client and closing WebSocket.
  """
  @callback on_join(auth_data :: AuthData.t(), state :: internal_state()) ::
              {:ok, internal_state()} | {{:error, error :: atom()}, internal_state()}

  @doc """
  Callback invoked when a peer is leaving the room.
  """
  @callback on_leave(peer_id :: Peer.peer_id(), state :: internal_state()) ::
              {:ok, internal_state()}

  @doc """
  Callback invoked before forwarding messages either peers.

  This mean this callback will be invoked every time message is forwarded or the room broadcasts 
  messages by itself (e.g. when peer joins the room).

  Room will forward_message message returned by this callback, ergo returning `{:ok, state}`
  will cause ignoring message.
  """
  @callback on_forward(
              message :: Message.t(),
              state :: internal_state()
            ) :: {:ok, internal_state()} | {:ok, Message.t(), internal_state()}

  @doc """
  Callback invoked when the room is shutting down.

  Useful for any cleanup required.
  """
  @callback on_terminate(state :: internal_state()) :: :ok

  @optional_callbacks on_init: 1,
                      on_join: 2,
                      on_leave: 2,
                      on_forward: 2,
                      on_terminate: 1

  @doc """
  Starts a room based on the given module, registers it in `Membrane.WebRTC.Server.Registry`
  (under the given name) and links it to the current process.

  Args are passed to module's `c:on_init/1` callback.
  """
  @spec start_link(args :: room_options) :: GenServer.on_start()
  def start_link(%{name: room_name} = args) do
    name = {:via, Registry, {Membrane.WebRTC.Server.Registry, room_name}}
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc """
  Creates a room with the given name and module under supervision of 
  `Membrane.WebRTC.Server.RoomSupervisor`. 
  """
  @spec start_supervised(room_name :: String.t(), module :: module()) ::
          DynamicSupervisor.on_start_child()
  def start_supervised(room_name, module) do
    child_spec = {Membrane.WebRTC.Server.Room, %{name: room_name, module: module}}
    DynamicSupervisor.start_child(RoomSupervisor, child_spec)
  end

  @doc """
  Creates a room with the given name under supervision of `Membrane.WebRTC.Server.RoomSupervisor`. 
  """
  @spec start_supervised(room_name :: String.t()) ::
          DynamicSupervisor.on_start_child()
  def start_supervised(room_name) do
    start_supervised(room_name, nil)
  end

  @doc """
  Adds the peer to the room. 

  `t:Membrane.WebRTC.Server.Message.joined_message/0` 
  is broadcasted to other peers after peer successfully joins the room. See
  [Initialization](initialization.html) for more info.
  """
  @spec join(room :: pid(), auth_data :: AuthData.t(), peer_pid :: pid()) ::
          :ok | {:error, atom()} | {:error, {atom(), any()}}
  def join(room, auth_data, peer_pid) do
    GenServer.call(room, {:join, auth_data, peer_pid})
  end

  @doc """
  Removes the peer from the room. 

  Broadcast `t:Membrane.WebRTC.Server.Message.left_message/0` to other peers if 
  given peer was in the room. 
  """
  @spec leave(room :: pid(), peer_id :: Peer.peer_id()) :: :ok
  def leave(room, peer_id) do
    GenServer.cast(room, {:leave, peer_id})
    :ok
  end

  @doc """
  Forwards the message to the addressees given under `message.to` key.

  Messages ment to be broadcasted should have `message.to` set to "all". Broadcasted message will
  be forwarded to all peers, except for sender (given under `message.from`).
  """
  @spec forward_message(room :: pid(), message :: Message.t()) ::
          :ok | {:error, :no_such_peer} | {:error, :unknown_error}
  def forward_message(room, %Message{to: peer_id} = message) when peer_id != nil do
    case GenServer.call(room, {:forward, message}) do
      :ok ->
        :ok

      {:error, :no_such_peer} ->
        Logger.error("Could not find peer")
        {:error, :no_such_peer}

      {:error, error} ->
        Logger.error("Unknown error, details: #{inspect(error)}")
        {:error, error}
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
  def init(%{name: name, module: nil}) do
    init(%{name: name, module: DefaultRoom})
  end

  @impl true
  def init(%{module: module} = args) do
    state = %State{peers: BiMap.new(), module: module}
    callback_exec(:on_init, [args], state)
  end

  @impl true
  def handle_call({:forward, message}, _from, state) do
    case try_forward_message(message, state) do
      {:ok, state} -> {:reply, :ok, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call({:join, auth_data, peer_pid}, _from, state) do
    case callback_exec(:on_join, [auth_data], state) do
      {:ok, state} ->
        peers = state.peers |> BiMap.put(auth_data.peer_id, peer_pid)
        state = %State{state | peers: peers}

        Process.monitor(peer_pid)

        broadcasted_message = %Message{
          data: %{peer_id: auth_data.peer_id},
          event: "joined",
          from: auth_data.peer_id,
          to: "all"
        }

        {:ok, state} = try_forward_message(broadcasted_message, state)
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

      message = %Message{event: "left", data: %{peer_id: peer_id}, to: "all"}
      try_forward_message(message, state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

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

  defp callback_exec(:on_forward, args, state) do
    case apply(state.module, :on_forward, args ++ [state.internal_state]) do
      {:ok, internal_state} ->
        {:ok, %State{state | internal_state: internal_state}}

      {:ok, message, internal_state} ->
        {:ok, message, %State{state | internal_state: internal_state}}
    end
  end

  defp callback_exec(:on_terminate, args, state),
    do: apply(state.module, :on_terminate, args ++ [state.internal_state])

  defp try_forward_message(message, state) do
    case callback_exec(:on_forward, [message], state) do
      {:ok, state} ->
        {:ok, state}

      {:ok, %Message{to: "all"} = message, state} ->
        forward_to_all(message, state.peers)
        {:ok, state}

      {:ok, message, state} ->
        addressees = message.to

        with :ok <-
               Bunch.Enum.try_each(addressees, fn peer -> check_peer(peer, state.peers) end) do
          Enum.each(addressees, fn peer ->
            BiMap.get(state.peers, peer) |> Peer.send_to_client(message)
          end)

          {:ok, state}
        end
    end
  end

  defp forward_to_all(%Message{from: sender} = message, peers) when not is_nil(sender) do
    peers
    |> BiMap.delete_key(sender)
    |> Enum.each(fn {_peer_id, pid} ->
      Peer.send_to_client(pid, message)
    end)

    :ok
  end

  defp forward_to_all(message, peers) do
    Enum.each(peers, fn {_peer_id, pid} ->
      Peer.send_to_client(pid, message)
    end)

    :ok
  end

  defp check_peer(adressee, peers) do
    case BiMap.get(peers, adressee) do
      nil ->
        {:error, :no_such_peer}

      _pid ->
        :ok
    end
  end

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)

      def on_init(_args),
        do: {:ok, %{}}

      def on_join(_auth_data, state),
        do: {:ok, state}

      def on_leave(_peer_id, state),
        do: {:ok, state}

      def on_forward(message, state) do
        {:ok, message, state}
      end

      def on_terminate(_state),
        do: :ok

      defoverridable on_init: 1,
                     on_join: 2,
                     on_leave: 2,
                     on_forward: 2,
                     on_terminate: 1
    end
  end
end
