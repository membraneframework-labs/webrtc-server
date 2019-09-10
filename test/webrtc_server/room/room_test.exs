defmodule Membrane.WebRTC.Server.RoomTest do
  use ExUnit.Case, async: true

  alias Membrane.WebRTC.Server.Message
  alias Membrane.WebRTC.Server.Room.State
  alias Membrane.WebRTC.Server.Support.{MockRoom, RoomHelper}

  @module Membrane.WebRTC.Server.Room

  describe "handle_cast" do
    test "should remove peer" do
      assert @module.handle_cast({:leave, "peer_2"}, state(2)) == {:noreply, state(1)}
    end

    test "should remove no peer" do
      assert @module.handle_cast({:leave, "peer_3"}, state(2)) == {:noreply, state(2)}
    end

    test "shouldn't receive broadcasted message when broadcaster is given" do
      @module.handle_cast({:broadcast, :ping, "peer_1"}, state(10, BiMap.new(), true))
      refute_received :ping
    end

    test "shouldn't change state nor send messages when broadcasting to empty room" do
      assert @module.handle_cast({:broadcast, :ping}, state(0)) == {:noreply, state(0)}
      refute_received :ping
    end
  end

  describe "handle_call: " do
    test "should receive sent ping" do
      ping_message = %Message{event: "ping", to: "peer_1"}
      @module.handle_call({:send, ping_message}, self(), state(5, BiMap.new(), true))
      assert_received ping_message
    end

    test "should not return :ok nor receive ping if peer not exists" do
      new_state = state(5, BiMap.new(), true)
      ping_message = %Message{event: "ping", to: "peer_-1"}

      refute @module.handle_call({:send, ping_message}, self(), new_state) ==
               {:reply, :ok, new_state}

      refute_received ^ping_message
    end

    test "should add peer to room" do
      auth_data = RoomHelper.create_auth(2)
      pid = RoomHelper.generate_pid(2, false)

      assert @module.handle_call({:join, auth_data, pid}, self(), state(1)) ==
               {:reply, :ok, state(2)}
    end

    test "should add peer to room with many peers" do
      auth_data = RoomHelper.create_auth(150)
      pid = RoomHelper.generate_pid(150, false)

      assert @module.handle_call(
               {:join, auth_data, pid},
               self(),
               state(149)
             ) ==
               {:reply, :ok, state(150)}
    end

    test "should add peer to empty room" do
      auth_data = RoomHelper.create_auth(1)

      assert @module.handle_call({:join, auth_data, self()}, self(), state(0)) ==
               {:reply, :ok, state(1)}
    end

    test "should replace already existing peer" do
      pid = RoomHelper.generate_pid(5, true)
      state = %State{peers: BiMap.new(%{"peer_1" => pid}), module: MockRoom}
      auth_data = RoomHelper.create_auth(1)

      assert @module.handle_call({:join, auth_data, pid}, self(), state(1)) ==
               {:reply, :ok, state}
    end
  end

  describe "init" do
    test "registry itself" do
      {:ok, pid} = @module.start_link(%{name: "name", module: MockRoom})
      assert Registry.lookup(Server.Registry, "name") == [{pid, nil}]
    end
  end

  describe "terminate" do
    test "should unregistry itself and not cause Registry termination" do
      Application.start(:logger)
      auth_data = RoomHelper.create_auth("id")

      assert {:ok, room_pid} = @module.start_link(%{name: "room", module: MockRoom})
      assert {:ok, mock_pid} = @module.start_link(%{name: "mock", module: MockRoom})
      @module.join(room_pid, auth_data, RoomHelper.generate_pid(0, false))
      assert :ok == GenServer.stop(room_pid, :normal)
      Process.sleep(20)
      assert Registry.lookup(Server.Registry, "mock") == [{mock_pid, nil}]
      assert Registry.lookup(Server.Registry, "room") == []
    end
  end

  def state(number_of_peers, map \\ BiMap.new(), real \\ false) do
    case number_of_peers do
      0 ->
        %State{peers: map, module: MockRoom}

      1 ->
        state(0, BiMap.put(map, "peer_1", self()))

      n ->
        name = "peer_" <> to_string(n)
        pid = RoomHelper.generate_pid(n, real)
        state(n - 1, BiMap.put(map, name, pid))
    end
  end
end
