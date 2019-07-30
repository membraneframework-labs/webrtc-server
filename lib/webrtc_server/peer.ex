defmodule Membrane.WebRTC.Server.Peer do
  @behaviour :cowboy_websocket
  require Logger
  alias Membrane.WebRTC.Server.Room

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
    Room.join(get_room_pid(room), peer_id, self())
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
    room_pid = get_room_pid(room)
    Room.leave(room_pid, peer_id)
    :ok
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
        {:reply, frames, %State{state | internal_state: internal_state}, :hibernate}

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
    room_pid = get_room_pid(room)
    Logger.info("Sending message to peer #{peer_id} from #{my_peer_id} in room #{room}")
    Room.send_message(room_pid, message, peer_id, my_peer_id)
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

  defp get_room_pid(room) do
    case Registry.match(Server.Registry, :room, room) do
      [{room_pid, ^room}] ->
        room_pid

      [] ->
        {:ok, room_pid} = Room.create(room)
        room_pid
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
