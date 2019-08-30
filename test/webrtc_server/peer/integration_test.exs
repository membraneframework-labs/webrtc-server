defmodule Membrane.WebRTC.Server.IntegrationTest do
  use ExUnit.Case, async: false

  alias Membrane.WebRTC.Server.{Message, Peer, Room}
  alias Membrane.WebRTC.Server.Peer.State
  alias Membrane.WebRTC.Server.{Support.CustomPeer, Support.MockPeer}

  @module Membrane.WebRTC.Server.Peer

  setup_all do
    Application.start(:logger)
    Registry.start_link(keys: :unique, name: Server.Registry)
    Logger.configure(level: :error)
  end

  setup do
    child_options = {Room, %{name: "room", module: Peer.DefaultRoom}}
    {:ok, pid} = start_supervised(child_options)
    insert_peers(10, pid, true)

    [
      peer_state: %State{
        room: "room",
        peer_id: "peer_10",
        module: MockPeer,
        internal_state: %{},
        room_module: Peer.DefaultRoom
      },
      room_pid: pid
    ]
  end

  describe "websocket_init" do
    test "should execute custom callback", ctx do
      state = %State{ctx.peer_state | module: CustomPeer}

      assert @module.websocket_init(state) ==
               {:ok, %State{state | internal_state: %{a: :a}}, :hibernate}
    end

    test "should return {:ok, state} when no callback provided", ctx do
      assert @module.websocket_init(ctx.peer_state) == {:ok, ctx.peer_state}
    end

    test "should cause joining room", ctx do
      @module.websocket_init(%State{ctx.peer_state | peer_id: "test_peer"})

      assert [{room_pid, :room}] = Registry.lookup(Server.Registry, "room")
      assert is_pid(room_pid)
      assert Process.alive?(room_pid)
      assert Room.send_message(room_pid, %Message{event: "ping", to: "test_peer"}) == :ok
    end

    test "with room that does not exists should cause creating room", ctx do
      state =
        ctx.peer_state |> Map.put(:room, "non-existant-room") |> Map.put(:peer_id, "test_peer")

      @module.websocket_init(state)

      assert [{room_pid, :room}] = Registry.lookup(Server.Registry, "non-existant-room")
      assert is_pid(room_pid)
      assert Process.alive?(room_pid)
      assert Room.send_message(room_pid, %Message{event: "ping", to: "test_peer"}) == :ok
    end
  end

  describe "handle frames" do
    test "sending correct message should not change state", ctx do
      {:ok, correct_message} = Jason.encode(%{"to" => "peer_1", "data" => %{}})

      assert @module.websocket_handle({:text, correct_message}, ctx.peer_state) ==
               {:ok, ctx.peer_state}
    end

    test "should receive message after sending correct one", ctx do
      {:ok, correct_message} =
        Jason.encode(%{"to" => "peer_1", "data" => %{}, "event" => "event"})

      @module.websocket_handle({:text, correct_message}, ctx.peer_state)

      assert_received %Membrane.WebRTC.Server.Message{
        data: %{},
        event: "event",
        from: "peer_10",
        to: "peer_1"
      }
    end

    test "should receive message modified by callback and not the original one", ctx do
      message = %{event: "modify", data: "a", to: "peer_1", from: "peer_10"}
      state = %State{ctx.peer_state | module: CustomPeer}
      modified = struct(Message, Map.put(message, :data, "ab"))
      assert @module.websocket_handle({:text, Jason.encode!(message)}, state) == {:ok, state}

      assert_received ^modified
    end

    test "should not receive message when on_message callback ignore it", ctx do
      message = %{event: "ignore", from: "peer_10"}
      state = %State{ctx.peer_state | module: CustomPeer}
      assert @module.websocket_handle({:text, Jason.encode!(message)}, state) == {:ok, state}
      ignored = struct(Message, message)
      refute_received ^ignored
    end

    test "should receive original message if callback return it", ctx do
      message = %{event: "just send it", data: "a", to: "peer_1", from: "peer_10"}
      state = %State{ctx.peer_state | module: CustomPeer}
      received = struct(Message, message)
      assert @module.websocket_handle({:text, Jason.encode!(message)}, state) == {:ok, state}

      assert_received ^received
    end

    test "should change internal state if callback return it", ctx do
      message = %{event: "change state", data: "brand new state", to: "peer_1", from: "peer_10"}
      state = %State{ctx.peer_state | module: CustomPeer}
      received = struct(Message, message)
      new_state = %State{state | internal_state: "brand new state"}
      assert @module.websocket_handle({:text, Jason.encode!(message)}, state) == {:ok, new_state}

      assert_received ^received
    end
  end

  describe "handle terminate" do
    test "should return :ok and receive message about leaving room by peer_10", ctx do
      assert @module.terminate(:normal, %{}, ctx.peer_state) == :ok
      assert_receive %Message{data: %{peer_id: "peer10"}, event: "left"}
    end
  end

  def insert_peers(number_of_peers, room, real \\ false)
  def insert_peers(1, room, _real), do: Room.join(room, "peer_1", self())

  def insert_peers(n, room, real) when n > 1 do
    Room.join(room, "peer_1", self())

    2..n
    |> Enum.map(fn num ->
      with peer_id <- "peer" <> to_string(num),
           pid <- generate_pid(num, real) do
        Room.join(room, peer_id, pid)
      end
    end)
  end

  def insert_peers(number_of_peers, room, real) do
    case number_of_peers do
      1 ->
        Room.join(room, "peer_1", self())

      n ->
        peer = "peer_" <> to_string(n)
        pid = generate_pid(n, real)
        Room.join(room, peer, pid)
        insert_peers(n - 1, room, real)
    end
  end

  def generate_pid(number, real) do
    case real do
      true ->
        spawn(fn -> :ok end)

      false ->
        IEx.Helpers.pid(0, number, 0)
    end
  end
end
