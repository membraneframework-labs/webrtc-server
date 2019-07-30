defmodule Membrane.WebRTC.Server.IntegrationTest do
  @module Membrane.WebRTC.Server.Peer
  alias Membrane.WebRTC.Server.{Peer, RoomTest, Room, Peer.State}
  use ExUnit.Case, async: false

  defmodule MockSocket do
    use Peer
  end

  setup_all do
    Application.start(:debug)
    Registry.start_link(keys: :duplicate, name: Server.Registry)
    Logger.configure(level: :error)
  end

  setup do
    child_spec = {Room, %{name: "room"}}
    {:ok, pid} = start_supervised(child_spec)
    insert_peers(10, pid, true)

    [
      peer_state: %State{
        room: "room",
        peer_id: "peer_10",
        module: MockSocket,
        internal_state: %{}
      },
      room_pid: pid
    ]
  end

  describe "handle frames" do
    test "sending correct message should not change state", ctx do
      {:ok, correct_message} = Jason.encode(%{"to" => "peer_1", "data" => %{}})

      assert @module.websocket_handle({:text, correct_message}, ctx[:peer_state]) ==
               {:ok, ctx[:peer_state]}
    end

    test "should receive message after sending correct one", ctx do
      {:ok, correct_message} = Jason.encode(%{"to" => "peer_1", "data" => %{}})

      @module.websocket_handle({:text, correct_message}, ctx[:peer_state])
      assert_received {:text, "{\"data\":{},\"from\":\"peer_10\",\"to\":\"peer_1\"}"}
    end

    test "sending wrong message should result in receiving error reply", ctx do
      {:ok, reply} = Jason.encode(%{"event" => :error, "description" => "invalid json"})

      assert @module.websocket_handle({:text, "invalid json"}, ctx[:peer_state]) ==
               {:reply, {:text, reply}, ctx[:peer_state]}
    end
  end

  describe "handle terminate" do
    test "should return :ok and receive message about leaving room by peer_10", ctx do
      assert @module.terminate(:normal, %{}, ctx[:peer_state]) == :ok
      assert_receive {:text, "{\"data\":{\"peer_id\":\"peer_10\"},\"event\":\"left\"}"}
    end
  end

  def insert_peers(number_of_peers, room, real \\ false) do
    case number_of_peers do
      0 ->
        :ok

      1 ->
        Room.join(room, "peer_1", self())

      n ->
        peer = "peer_" <> to_string(n)
        pid = RoomTest.generate_pid(n, real)
        Room.join(room, peer, pid)
        insert_peers(n - 1, room, real)
    end
  end
end
