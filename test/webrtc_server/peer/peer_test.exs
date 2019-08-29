defmodule Membrane.WebRTC.Server.PeerTest do
  use ExUnit.Case, async: true

  alias Membrane.WebRTC.Server.Message

  alias Membrane.WebRTC.Server.{
    Peer,
    Peer.State,
    Peer.Options,
    Support.MockPeer,
    Support.ErrorPeer,
    Support.CustomPeer
  }

  @module Peer

  setup_all do
    Application.start(:logger)
    Logger.configure(level: :error)
  end

  setup do
    [
      state: %State{
        room: "room",
        peer_id: "1",
        module: MockPeer,
        internal_state: nil,
        room_module: Peer.DefaultRoom
      },
      mock_request: %{
        method: "GET",
        pid: spawn(fn -> :ok end),
        streamid: 1
      }
    ]
  end

  describe "init" do
    test "should return request with 403 status code when callback authenticate return {:error, reason}",
         ctx do
      assert @module.init(ctx.mock_request, %Options{module: ErrorPeer}) ==
               {:ok, :cowboy_req.reply(403, ctx.mock_request), %{}}
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

      assert_received %Message{data: %{description: "Invalid JSON", details: _}, event: "error"}
    end
  end

  describe "handle info" do
    test "should reply with same message", ctx do
      message = %Message{event: :ok, data: "same"}
      {:ok, encoded} = message |> Map.from_struct() |> Jason.encode()

      assert @module.websocket_info(message, ctx.state) ==
               {:reply, {:text, encoded}, ctx.state}
    end

    test "with DOWN message should return {:stop, state}", ctx do
      message = {:DOWN, make_ref(), :process, self(), :exit_reason}
      assert @module.websocket_info(message, ctx.state) == {:stop, ctx.state}
    end

    test "with DOWN message should receive message about roon closing", ctx do
      message = {:DOWN, make_ref(), :process, self(), :exit_reason}
      @module.websocket_info(message, ctx.state)
      assert_receive %Message{event: :room_closed, data: %{reason: :exit_reason}}
    end
  end
end
