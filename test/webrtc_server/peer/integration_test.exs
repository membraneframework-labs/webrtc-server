defmodule Membrane.WebRTC.Server.IntegrationTest do
  use ExUnit.Case, async: false

  alias Membrane.WebRTC.Server.{Message, Peer, Room}
  alias Membrane.WebRTC.Server.Peer.{AuthData, State}

  alias Membrane.WebRTC.Server.Support.{
    CustomPeer,
    ErrorRoom,
    MockPeer,
    RoomHelper
  }

  @module Membrane.WebRTC.Server.Peer

  setup_all do
    Application.start(:logger)
    Registry.start_link(keys: :unique, name: Membrane.WebRTC.Server.Registry)
    Logger.configure(level: :debug)

    authorised = %State{
      room: "room",
      peer_id: "peer_10",
      module: MockPeer,
      internal_state: %{},
      auth_data: :already_authorised
    }

    unauthorised = %State{authorised | auth_data: %AuthData{peer_id: "peer_10", credentials: %{}}}

    [
      authorised_state: authorised,
      unauthorised_state: unauthorised
    ]
  end

  setup do
    child_options = {Room, %{name: "room", module: Peer.DefaultRoom}}
    {:ok, pid} = start_supervised(child_options)
    insert_peers(10, pid, true)

    [room_pid: pid]
  end

  describe "websocket_init should" do
    test "cause joining room", ctx do
      auth_data = %AuthData{ctx.unauthorised_state.auth_data | peer_id: "test_peer"}

      state =
        ctx.unauthorised_state
        |> Map.put(:peer_id, "test_peer")
        |> Map.put(:auth_data, auth_data)

      after_init_state = %State{state | auth_data: :already_authorised}

      assert @module.websocket_init(state) == {:ok, after_init_state}

      assert [{room_pid, nil}] = Registry.lookup(Membrane.WebRTC.Server.Registry, "room")
      assert is_pid(room_pid)
      assert Process.alive?(room_pid)
      assert Room.send_message(room_pid, %Message{event: "ping", to: "test_peer"}) == :ok
    end

    test "receive error message and :stop when Room.join fail", ctx do
      stop_supervised(Room)
      child_options = {Room, %{name: "error_room", module: ErrorRoom}}
      {:ok, _pid} = start_supervised(child_options)

      state = %State{ctx.unauthorised_state | room: "error_room"}
      assert @module.websocket_init(state) == {:ok, state}
      assert_receive :stop

      encoded =
        %Message{
          event: "error",
          data: %{description: "Could not join room", details: "this_is_supposed_to_fail"}
        }
        |> Jason.encode!()

      received = {:message, encoded}

      assert_receive ^received
    end
  end

  describe "handle frames should" do
    test "not change state if frames are correct messages", ctx do
      correct_message = Jason.encode!(%{"to" => "peer_1", "data" => %{}})

      assert @module.websocket_handle({:text, correct_message}, ctx.authorised_state) ==
               {:ok, ctx.authorised_state}
    end

    test "receive message after sending correct one", ctx do
      correct_message = Jason.encode!(%{"to" => "peer_1", "data" => %{}, "event" => "event"})

      @module.websocket_handle({:text, correct_message}, ctx.authorised_state)

      message = %Membrane.WebRTC.Server.Message{
        data: %{},
        event: "event",
        from: "peer_10",
        to: "peer_1"
      }

      received = {:message, message |> Jason.encode!()}
      assert_received ^received
    end

    test "receive message modified by callback and not the original one", ctx do
      message = %{event: "modify", data: "a", to: "peer_1", from: "peer_10"}
      state = %State{ctx.authorised_state | module: CustomPeer}
      modified = {:message, struct(Message, Map.put(message, :data, "ab")) |> Jason.encode!()}
      assert @module.websocket_handle({:text, Jason.encode!(message)}, state) == {:ok, state}

      assert_received ^modified
    end

    test "not receive message when on_send callback ignore it", ctx do
      message = %{event: "ignore", from: "peer_10"}
      state = %State{ctx.authorised_state | module: CustomPeer}
      assert @module.websocket_handle({:text, Jason.encode!(message)}, state) == {:ok, state}
      ignored = {:message, struct(Message, message) |> Jason.encode!()}
      refute_received ^ignored
    end

    test "receive original message if callback return it", ctx do
      message = %{event: "just send it", data: "a", to: "peer_1", from: "peer_10"}
      state = %State{ctx.authorised_state | module: CustomPeer}
      received = {:message, struct(Message, message) |> Jason.encode!()}
      assert @module.websocket_handle({:text, Jason.encode!(message)}, state) == {:ok, state}

      assert_received ^received
    end

    test "change internal state if callback return it", ctx do
      message = %{event: "change state", data: "brand new state", to: "peer_1", from: "peer_10"}
      state = %State{ctx.authorised_state | module: CustomPeer}
      received = {:message, struct(Message, message) |> Jason.encode!()}
      new_state = %State{state | internal_state: "brand new state"}
      assert @module.websocket_handle({:text, Jason.encode!(message)}, state) == {:ok, new_state}

      assert_received ^received
    end
  end

  describe "handle terminate" do
    test "should return :ok and receive message about leaving room by peer_10", ctx do
      assert @module.terminate(:normal, %{}, ctx.authorised_state) == :ok
      message = %Message{data: %{peer_id: "peer_10"}, event: "left"}
      received = {:message, message |> Jason.encode!()}
      assert_receive ^received
    end
  end

  def insert_peers(number_of_peers, room, real \\ false)

  def insert_peers(1, room, _real) do
    auth_data = %AuthData{peer_id: "peer_1", credentials: %{}}
    Room.join(room, auth_data, self())
  end

  def insert_peers(n, room, real) when n > 1 do
    Room.join(room, %AuthData{peer_id: "peer_1", credentials: %{}}, self())

    2..n
    |> Enum.map(fn num ->
      with auth_data <- %AuthData{peer_id: "peer_" <> to_string(num), credentials: %{}},
           pid <- RoomHelper.generate_pid(num, real) do
        Room.join(room, auth_data, pid)
      end
    end)
  end
end
