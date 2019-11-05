defmodule Membrane.WebRTC.Server.PeerTest do
  use ExUnit.Case, async: false

  alias Membrane.WebRTC.Server.Message
  alias Membrane.WebRTC.Server.Room
  alias Membrane.WebRTC.Server.Peer.{Options, State}

  alias Membrane.WebRTC.Server.Support.{
    CustomPeer,
    InitErrorPeer,
    MockPeer,
    MockRoom,
    ParseErrorPeer
  }

  @module Membrane.WebRTC.Server.Peer

  setup_all do
    Application.start(:logger)
    Logger.configure(level: :error)

    registry_spec = Registry.child_spec(keys: :unique, name: MockRegistry)
    start_supervised(registry_spec)
    room_spec = {Room, %Room.Options{name: "room", module: MockRoom, registry: MockRegistry}}
    {:ok, pid} = start_supervised(room_spec)

    [
      state: %State{
        room: pid,
        peer_id: "1",
        module: MockPeer,
        internal_state: nil,
        auth_data: :already_authorised
      },
      mock_request: %{
        method: "GET",
        pid: spawn(fn -> :ok end),
        streamid: 1
      }
    ]
  end

  describe "init should" do
    test "return request with 400 status code when callback parse_request return error tuple",
         ctx do
      assert @module.init(ctx.mock_request, %Options{
               module: ParseErrorPeer,
               registry: MockRegistry
             }) ==
               {:ok, :cowboy_req.reply(400, ctx.mock_request), %{}}
    end

    test "return request with 401 status code when callback authenticate return {:error, reason}",
         ctx do
      assert @module.init(ctx.mock_request, %Options{
               module: InitErrorPeer,
               registry: MockRegistry
             }) ==
               {:ok, :cowboy_req.reply(401, ctx.mock_request), %{}}
    end

    test "initialize websocket after successful authentication", ctx do
      request = ctx.mock_request

      assert {:cowboy_websocket, request, %State{}, _} =
               @module.init(request, %Options{module: MockPeer, registry: MockRegistry})
    end

    test "return custom WebSocket options and initialize internal state correctly", ctx do
      request = ctx.mock_request

      assert {:cowboy_websocket, request, %State{internal_state: :custom_internal_state},
              %{idle_timeout: 20}} =
               @module.init(request, %Options{module: CustomPeer, registry: MockRegistry})
    end
  end

  describe "handle frame" do
    test "answer with pong frame", ctx do
      assert @module.websocket_handle(:ping, ctx.state) == {:reply, :pong, ctx.state}
    end

    test "answer with pong and data frame", ctx do
      assert @module.websocket_handle({:ping, "data"}, ctx.state) ==
               {:reply, {:pong, "data"}, ctx.state}
    end

    test "answer with pong text", ctx do
      assert @module.websocket_handle({:text, "ping"}, ctx.state) ==
               {:reply, {:text, "pong"}, ctx.state}
    end

    test "receive invalid json message", ctx do
      @module.websocket_handle({:text, "%{not json}"}, ctx.state)

      encoded =
        %Message{data: %{description: "Invalid JSON", details: "%{not json}"}, event: "error"}
        |> Jason.encode!()

      received = {:message, encoded}
      assert_received ^received
    end
  end
end
