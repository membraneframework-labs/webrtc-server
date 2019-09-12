defmodule Membrane.WebRTC.Server.PeerTest do
  use ExUnit.Case, async: true

  alias Membrane.WebRTC.Server.Message
  alias Membrane.WebRTC.Server.Peer
  alias Membrane.WebRTC.Server.Peer.{Options, State}
  alias Membrane.WebRTC.Server.Support.{CustomPeer, InitErrorPeer, MockPeer, ParseErrorPeer}

  @module Peer

  setup_all do
    Application.start(:logger)
    Logger.configure(level: :error)

    [
      state: %State{
        room: "room",
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

  describe "init" do
    test "should return request with 400 status code when callback parse_auth_request return {:error, reason}",
         ctx do
      assert @module.init(ctx.mock_request, %Options{module: ParseErrorPeer}) ==
               {:ok, :cowboy_req.reply(400, ctx.mock_request), %{}}
    end

    test "should return request with 401 status code when callback authenticate return {:error, reason}",
         ctx do
      assert @module.init(ctx.mock_request, %Options{module: InitErrorPeer}) ==
               {:ok, :cowboy_req.reply(401, ctx.mock_request), %{}}
    end

    test "should initialize websocket after successful authentication", ctx do
      request = ctx.mock_request

      assert {:cowboy_websocket, request, %State{}, _} =
               @module.init(request, %Options{module: MockPeer})
    end

    test "should return custom WebSocket options and initialize internal state correctly", ctx do
      request = ctx.mock_request

      assert {:cowboy_websocket, request, %State{internal_state: :custom_internal_state},
              %{idle_timeout: 20}} = @module.init(request, %Options{module: CustomPeer})
    end
  end

  describe "handle frame" do
    test "should answer with pong frame", ctx do
      assert @module.websocket_handle(:ping, ctx.state) == {:reply, :pong, ctx.state}
    end

    test "should answer with pong and data frame", ctx do
      assert @module.websocket_handle({:ping, "data"}, ctx.state) ==
               {:reply, {:pong, "data"}, ctx.state}
    end

    test "should answer with pong text", ctx do
      assert @module.websocket_handle({:text, "ping"}, ctx.state) ==
               {:reply, {:text, "pong"}, ctx.state}
    end

    test "should receive invalid json message", ctx do
      @module.websocket_handle({:text, "%{not json}"}, ctx.state)

      encoded =
        %Message{data: %{description: "Invalid JSON", details: "%{not json}"}, event: "error"}
        |> Jason.encode!()

      received = {:message, encoded}
      assert_received ^received
    end
  end

  describe "handle info" do
    test "with DOWN message should :stop message", ctx do
      message = {:DOWN, make_ref(), :process, self(), :exit_reason}
      @module.websocket_info(message, ctx.state)
      assert_receive :stop
    end

    test "with DOWN message should receive message about roon closing", ctx do
      message = {:DOWN, make_ref(), :process, self(), :exit_reason}
      @module.websocket_info(message, ctx.state)

      encoded =
        %Message{event: "error", data: %{description: "Room closed", details: :exit_reason}}
        |> Jason.encode!()

      received = {:message, encoded}
      assert_receive ^received
    end
  end
end
