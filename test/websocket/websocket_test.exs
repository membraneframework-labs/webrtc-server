defmodule Membrane.WebRTC.Server.WebSocketTest do
  @module Membrane.WebRTC.Server.WebSocket
  alias Membrane.WebRTC.Server.WebSocket.State
  use ExUnit.Case, async: true

  describe "handle frame" do
    test "should answer with pong frame" do
      assert @module.websocket_handle(:ping, state()) == {:reply, :pong, state()}
    end

    test "should answer with pong and data frame" do
      assert @module.websocket_handle({:ping, "data"}, state()) ==
               {:reply, {:pong, "data"}, state()}
    end

    test "should answer with pong text" do
      assert @module.websocket_handle({:text, "ping"}, state()) ==
               {:reply, {:text, "pong"}, state()}
    end

    test "should return invalid json message" do
      {:ok, error_message} = Jason.encode(%{"event" => :error, "description" => "invalid json"})

      assert @module.websocket_handle({:text, "%{not json}"}, state()) ==
               {:reply, {:text, error_message}, state()}
    end
  end

  describe "handle info" do
    test "should reply with ok" do
      assert @module.websocket_info("info message", state()) ==
               {:reply, {:text, "ok"}, state()}
    end
  end

  def state(_ctx \\ nil) do
    Application.start(:logger)
    Logger.configure(level: :error)
    %State{room: "room", peer_id: "1", module: nil}
  end
end
