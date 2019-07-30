defmodule Membrane.WebRTC.Server.Peer do
  @behaviour :cowboy_websocket
  require Logger

  @type internal_state :: any

  defmodule State do
    @enforce_keys [:module, :room, :peer_id, :internal_state]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room: String.t(),
            peer_id: String.t(),
            module: module() | nil,
            internal_state: Membrane.WebRTC.Server.Peer.internal_state()
          }
  end

  defmodule Context do
    @enforce_keys [:room, :peer_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room: String.t(),
            peer_id: String.t()
          }
  end

  defmodule Spec do
    @enforce_keys [:module]
    defstruct [:custom_spec] ++ @enforce_keys

    @type t :: %__MODULE__{
            module: module() | nil,
            custom_spec: any
          }
  end

  @callback authenticate(request :: :cowboy_req.req(), spec :: any) ::
              {:ok, %{room: String.t(), state: internal_state}}
              | {:ok, %{room: String.t()}}
              | {:error, reason :: any}

  @callback on_init(
              request :: :cowboy_req.req(),
              context :: Context.t(),
              state :: internal_state
            ) ::
              {:cowboy_websocket, :cowboy_req.req(), internal_state}
              | {:cowboy_websocket, :cowboy_req.req(), internal_state, :cowboy_websocket.opts()}

  @callback on_websocket_init(context :: Context.t(), state :: internal_state) ::
              {:ok, internal_state}
              | {:ok, internal_state, :hibernate}
              | {:reply, :cow_ws.frame() | [:cow_ws.frame()], internal_state}
              | {:reply, :cow_ws.frame() | [:cow_ws.frame()], internal_state, :hibernate}
              | {:stop, internal_state}

  @impl true
  def init(request, %Spec{module: module} = spec) do
    case(callback_exec(module, :authenticate, [request], spec)) do
      {:ok, %{room: room, state: internal_state}} ->
        state = %State{
          room: room,
          peer_id: make_peer_id(),
          module: module,
          internal_state: internal_state
        }

        callback_exec(module, :on_init, [request], state)

      {:error, reason} ->
        Logger.error("Authentication error, reason: #{inspect(reason)}")
        request = :cowboy_req.reply(403, request)
        {:ok, request, %{}}
    end
  end

  @impl true
  def websocket_init(%State{room: room, peer_id: peer_id} = state) do
    join_room(room, peer_id)
    callback_exec(state.module, :on_websocket_init, [], state)
  end

  @impl true
  def websocket_handle({:text, "ping"}, state) do
    {:reply, {:text, "pong"}, state}
  end

  @impl true
  def websocket_handle(:ping, state),
    do: {:reply, :pong, state}

  @impl true
  def websocket_handle({:ping, data}, state),
    do: {:reply, {:pong, data}, state}

  @impl true
  def websocket_handle({:text, text}, state),
    do: text |> Jason.decode() |> handle_message(state)

  @impl true
  def websocket_handle(_frame, state) do
    Logger.warn("Non-text frame")
    {:ok, state}
  end

  @impl true
  def websocket_info(message, state) do
    {:reply, message, state}
  end

  @impl true
  def terminate(_reason, _req, %State{room: room, peer_id: peer_id}) do
    Logger.info("Terminating peer #{peer_id}")
    leave_room(room, peer_id)
  end

  @impl true
  def terminate(_reason, _req, _state) do
    Logger.info("Terminating peer")
    :ok
  end

  defp callback_exec(module, :on_init, [request], state) do
    args = [request, %Context{room: state.room, peer_id: state.peer_id}, state.internal_state]

    case apply(module, :on_init, args) do
      {:cowboy_websocket, request, internal_state} ->
        {:cowboy_websocket, request, %State{state | internal_state: internal_state}}

      {:cowboy_websocket, request, internal_state, opts} ->
        {:cowboy_websocket, request, %State{state | internal_state: internal_state}, opts}
    end
  end

  defp callback_exec(module, :on_websocket_init, [], state) do
    args = [%Context{room: state.room, peer_id: state.peer_id}, state.internal_state]

    case apply(module, :on_websocket_init, args) do
      {:ok, internal_state} ->
        {:ok, %State{state | internal_state: internal_state}}

      {:ok, internal_state, :hibernate} ->
        {:ok, %State{state | internal_state: internal_state}, :hibernate}

      {:reply, frames, internal_state} ->
        {:reply, frames, %State{state | internal_state: internal_state}}

      {:reply, frames, internal_state, :hibernate} ->
        {:reply, frames, %State{state | internal_state: internal_state}}

      {:stop, internal_state} ->
        {:stop, %State{state | internal_state: internal_state}}
    end
  end

  defp callback_exec(module, :authenticate, args, spec) do
    case apply(module, :authenticate, args ++ [spec.custom_spec]) do
      {:ok, room: room} -> {:ok, %{room: room, state: nil}}
      result -> result
    end
  end

  defp handle_message(
         {:ok, %{"to" => peer_id, "data" => _data} = message},
         %State{peer_id: my_peer_id, room: room} = state
       ) do
    Logger.info("Sending message to peer #{peer_id} from #{my_peer_id} in room #{room}")
    send_message(my_peer_id, peer_id, message, room)
    {:ok, state}
  end

  defp handle_message({:error, _jason_error}, state) do
    Logger.warn("Wrong message")
    {:ok, encoded} = Jason.encode(%{"event" => :error, "description" => "invalid json"})
    {:reply, {:text, encoded}, state}
  end

  defp make_peer_id() do
    "#Reference" <> peer_id = Kernel.inspect(Kernel.make_ref())
    peer_id
  end

  defp join_room(room, peer_id) do
    if(Registry.match(Server.Registry, :room, room) == []) do
      {:ok, _pid} = create_room(room)
    end

    [{room_pid, ^room}] = Registry.match(Server.Registry, :room, room)

    {:ok, message} = Jason.encode(%{"event" => :joined, "data" => %{peer_id: peer_id}})

    GenServer.cast(room_pid, {:broadcast, {:text, message}})
    GenServer.cast(room_pid, {:add, peer_id, self()})
  end

  defp leave_room(room, peer_id) do
    case Registry.match(Server.Registry, :room, room) do
      [{room_pid, ^room}] ->
        {:ok, message} =
          Jason.encode(%{
            "event" => :left,
            "data" => %{"peer_id" => peer_id}
          })

        GenServer.cast(room_pid, {:remove, peer_id})
        GenServer.cast(room_pid, {:broadcast, {:text, message}})
        :ok

      [] ->
        Logger.error("Couldn't find room #{room}")
        {:error, %{}}
    end
  end

  defp create_room(room) do
    child_spec = {Membrane.WebRTC.Server.Room, %{name: room}}
    Logger.info("Creating room #{room}")
    DynamicSupervisor.start_child(Membrane.WebRTC.Server, child_spec)
  end

  defp send_message(from, to, message, room) do
    {:ok, message} = Map.put(message, "from", from) |> Jason.encode()
    [{room_pid, ^room}] = Registry.match(Server.Registry, :room, room)

    case GenServer.call(room_pid, {:send, {:text, message}, to}) do
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

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)

      def authenticate(_request, _spec),
        do: {:ok, room: "room"}

      def on_init(request, _context, state) do
        opts = %{idle_timeout: 1000 * 60 * 15}
        {:cowboy_websocket, request, state, opts}
      end

      def on_websocket_init(_context, state),
        do: {:ok, state}

      defoverridable authenticate: 2,
                     on_init: 3,
                     on_websocket_init: 2
    end
  end
end
