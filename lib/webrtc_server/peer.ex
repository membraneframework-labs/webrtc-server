defmodule Membrane.WebRTC.Server.Peer do
  @behaviour :cowboy_websocket
  require Logger
  alias __MODULE__.{Context, Spec, State}
  alias Membrane.WebRTC.Server.{Message, Room}
  @type internal_state :: any

  @doc """
  Callback invoked before initialization of WebSocket.
  Peer will later join (or create and join) room with name returned by callback.
  Returning {:error, reason} will cause aborting initialization of WebSocket.
  """
  @callback authenticate(request :: :cowboy_req.req(), spec :: any) ::
              {:ok, %{room: String.t(), state: internal_state}}
              | {:ok, %{room: String.t()}}
              | {:error, reason :: any}

  @doc """
  Callback nvoked before initialization of WebSocket, after successful authentication.
  Useful for setting custom Cowboy WebSocket options, like timeout or maximal frame size.
  """
  @callback on_init(
              request :: :cowboy_req.req(),
              context :: Context.t(),
              state :: internal_state
            ) ::
              {:cowboy_websocket, :cowboy_req.req(), internal_state}
              | {:cowboy_websocket, :cowboy_req.req(), internal_state, :cowboy_websocket.opts()}

  @doc """
  Callback invoked after initialization of WebSocket.
  Useful for setting up internal state or informing client about successful authentication and initialization. 
  """
  @callback on_websocket_init(context :: Context.t(), state :: internal_state) ::
              {:ok, internal_state}
              | {:ok, internal_state, :hibernate}
              | {:reply, :cow_ws.frame() | [:cow_ws.frame()], internal_state}
              | {:reply, :cow_ws.frame() | [:cow_ws.frame()], internal_state, :hibernate}
              | {:stop, internal_state}

  @doc """
  Callback after successful decoding JSON message received via `websocket_handle({:test, message}, state)`.
  Peer will proceed to send message returned by this callback to Room, ergo returning {:ok, state} will cause ignoring message.
  Useful for modyfing or ignoring messages.
  """
  @callback on_message(message :: Message.t(), context :: Context.t(), state :: internal_state) ::
              {:ok, Message.t(), internal_state}
              | {:ok, internal_state}

  defmodule DefaultRoom do
    use Room
  end

  @impl true
  def init(request, %Spec{room_module: nil} = spec),
    do: init(request, %Spec{spec | room_module: DefaultRoom})

  @impl true
  def init(request, %Spec{module: module, room_module: room_module} = spec) do
    case(callback_exec(module, :authenticate, [request], spec)) do
      {:ok, %{room: room, state: internal_state}} ->
        state = %State{
          room: room,
          peer_id: make_peer_id(),
          module: module,
          internal_state: internal_state,
          room_module: room_module
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
    room_pid = get_room_pid(room, state)
    Room.join(room_pid, peer_id, self())
    Process.monitor(room_pid)
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
  def websocket_info(%Message{} = message, state) do
    {:ok, encoded} = message |> Map.from_struct() |> Jason.encode()
    {:reply, {:text, encoded}, state}
  end

  @impl true
  def websocket_info({:DOWN, _reference, :process, _pid, reason}, state) do
    message = %Message{event: :room_closed, data: %{reason: reason}}
    send(self(), message)
    {:stop, state}
  end

  @impl true
  def terminate(_reason, _req, %State{peer_id: peer_id}) do
    Logger.info("Terminating peer #{peer_id}")
    :ok
  end

  defp callback_exec(module, :on_init, [request], state) do
    args = prepare_args(state, [request])

    case apply(module, :on_init, args) do
      {:cowboy_websocket, request, internal_state} ->
        {:cowboy_websocket, request, %State{state | internal_state: internal_state}}

      {:cowboy_websocket, request, internal_state, opts} ->
        {:cowboy_websocket, request, %State{state | internal_state: internal_state}, opts}
    end
  end

  defp callback_exec(module, :on_websocket_init, [], state) do
    args = prepare_args(state)

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

  defp callback_exec(module, :on_message, [message], state) do
    args = prepare_args(state, [message])

    case apply(module, :on_message, args) do
      {:ok, internal_state} ->
        {:ok, %State{state | internal_state: internal_state}}

      {:ok, %Message{} = message, internal_state} ->
        room_pid = get_room_pid(state.room, state)
        Room.send_message(room_pid, message)
        {:ok, %State{state | internal_state: internal_state}}
    end
  end

  defp handle_message(
         {:ok, %{"data" => data, "event" => event, "to" => to}},
         %State{module: module, peer_id: peer_id} = state
       ) do
    message = %Message{data: data, event: event, from: peer_id, to: to}
    callback_exec(module, :on_message, [message], state)
  end

  defp handle_message({:ok, _message}, state) do
    send(self(), %Message{event: "error", data: %{desciption: "Invalid message"}})
    {:ok, state}
  end

  defp handle_message({:error, jason_error}, state) do
    Logger.warn("Wrong message")

    send(self(), %Message{
      event: "error",
      data: %{description: "Invalid JSON", details: jason_error}
    })

    {:ok, state}
  end

  defp make_peer_id() do
    "#Reference" <> peer_id = Kernel.inspect(Kernel.make_ref())
    peer_id
  end

  defp get_room_pid(room, %State{room_module: room_module}) do
    case Registry.lookup(Server.Registry, room) do
      [{room_pid, :room}] ->
        room_pid

      [] ->
        {:ok, room_pid} = Room.create(room, room_module)
        room_pid
    end
  end

  defp prepare_args(state, args \\ []),
    do: args ++ [%Context{peer_id: state.peer_id, room: state.room}, state.internal_state]

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

      def on_message(message, _context, state),
        do: {:ok, message, state}

      defoverridable authenticate: 2,
                     on_init: 3,
                     on_websocket_init: 2,
                     on_message: 3
    end
  end
end
