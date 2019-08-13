defmodule Membrane.WebRTC.Server.PeerTest do
  @module Membrane.WebRTC.Server.Peer
  alias Membrane.WebRTC.Server.Message
  alias Membrane.WebRTC.Server.Peer.State
  use ExUnit.Case, async: true

  setup_all do
    Application.start(:logger)
    Logger.configure(level: :error)
  end

  setup do
    [state: %State{room: "room", peer_id: "1", module: nil, internal_state: %{}}]
  end

  describe "handle frame" do
    test "should answer with pong frame", ctx do
      assert @module.websocket_handle(:ping, ctx[:state]) == {:reply, :pong, ctx[:state]}
    end

    test "should answer with pong and data frame", ctx do
      assert @module.websocket_handle({:ping, "data"}, ctx[:state]) ==
               {:reply, {:pong, "data"}, ctx[:state]}
    end

    test "should answer with pong text", ctx do
      assert @module.websocket_handle({:text, "ping"}, ctx[:state]) ==
               {:reply, {:text, "pong"}, ctx[:state]}
    end

    test "should receive invalid json message", ctx do
      @module.websocket_handle({:text, "%{not json}"}, ctx[:state])

      assert_received %Message{data: %{description: "Invalid JSON", details: _}, event: "error"}
    end
  end

  describe "handle info" do
    test "should reply with same message", ctx do
      message = %Message{event: :ok, data: "same"}
      {:ok, encoded} = message |> Map.from_struct() |> Jason.encode()

      assert @module.websocket_info(message, ctx[:state]) ==
               {:reply, {:text, encoded}, ctx[:state]}
    end
  end
end
