defmodule Membrane.WebRTC.Server.RoomTest do
  @module Membrane.WebRTC.Server.Room
  alias Membrane.WebRTC.Server.{Room.State, Message}

  use ExUnit.Case, async: true

  defmodule MockModule do
    use Membrane.WebRTC.Server.Room
  end

  describe "handle_info:" do
    test "should remove peer" do
      assert @module.handle_info({:leave, "peer_2"}, state(2)) == {:noreply, state(1)}
    end

    test "should remove no peer" do
      assert @module.handle_info({:leave, "peer_3"}, state(2)) == {:noreply, state(2)}
    end

    test "remove last peer from room and close room" do
      assert @module.handle_info({:leave, "peer_1"}, state(1)) == {:stop, :normal, state(0)}
    end

    test "should add peer to room" do
      assert @module.handle_info({:join, "peer_2", IEx.Helpers.pid("0.2.0")}, state(1)) ==
               {:noreply, state(2)}
    end

    test "should add peer to room with many peers" do
      assert @module.handle_info({:join, "peer_150", IEx.Helpers.pid("0.150.0")}, state(149)) ==
               {:noreply, state(150)}
    end

    test "should add peer to empty room" do
      assert @module.handle_info({:join, "peer_1", self()}, state(0)) == {:noreply, state(1)}
    end

    test "should raise when given pid isn't a pid" do
      assert_raise FunctionClauseError,
                   ~r/no function clause matching in Membrane.WebRTC.Server.Room.handle_info\/2/,
                   fn -> @module.handle_info({:join, "peer_10", :not_a_pid}, state(4)) end
    end

    test "should replace already existing peer" do
      pid = generate_pid(5, true)

      assert @module.handle_info({:join, "peer_1", pid}, state(1)) ==
               {:noreply,
                %State{
                  peers: BiMap.new(%{"peer_1" => pid}),
                  module: MockModule
                }}
    end

    test "shouldn't receive broadcasted message when broadcaster is given" do
      @module.handle_info({:broadcast, :ping, "peer_1"}, state(10, BiMap.new(), true))
      refute_received :ping
    end

    test "shouldn't change state nor send messages when broadcasting to empty room" do
      assert @module.handle_info({:broadcast, :ping}, state(0)) == {:noreply, state(0)}
      refute_received :ping
    end
  end

  describe "handle_call: " do
    test "should receive sent ping" do
      ping_message = %Message{event: :ping, to: "peer_1"}
      @module.handle_call({:send, ping_message}, self(), state(5, BiMap.new(), true))
      assert_received ping_message
    end

    test "should not return :ok nor receive ping if peer not exists" do
      new_state = state(5, BiMap.new(), true)
      ping_message = %Message{event: :ping, to: "peer_-1"}

      refute @module.handle_call({:send, ping_message}, self(), new_state) ==
               {:reply, :ok, new_state}

      refute_received ^ping_message
    end
  end

  describe "init" do
    test "registry itself" do
      {:ok, pid} = @module.start_link(%{name: "name", module: MockModule})
      assert Registry.lookup(Server.Registry, "name") == [{pid, :room}]
    end
  end

  describe "terminate" do
    test "should receive process termination message after last peer leave" do
      assert {:ok, room_pid} = @module.create("room", MockModule)
      Process.monitor(room_pid)
      @module.join(room_pid, "peer_id", generate_pid(0, false))
      @module.leave(room_pid, "peer_id")
      assert_receive({:DOWN, _reference, :process, ^room_pid, _reason})
    end

    test "should unregistry itself and not cause Registry termination" do
      Application.start(:logger)
      Logger.configure(level: :error)

      assert {:ok, room_pid} = @module.create("room", MockModule)
      assert {:ok, mock_pid} = @module.start_link(%{name: "mock", module: MockModule})
      @module.join(room_pid, "peer_id", generate_pid(0, false))
      @module.leave(room_pid, "peer_id")
      Process.sleep(20)
      assert Registry.lookup(Server.Registry, "mock") == [{mock_pid, :room}]
      assert Registry.lookup(Server.Registry, "room") == []
    end
  end

  def state(number_of_peers, map \\ BiMap.new(), real \\ false) do
    case number_of_peers do
      0 ->
        %State{peers: map, module: MockModule}

      1 ->
        state(0, BiMap.put(map, "peer_1", self()))

      n ->
        name = "peer_" <> to_string(n)
        pid = generate_pid(n, real)
        state(n - 1, BiMap.put(map, name, pid))
    end
  end

  def generate_pid(number, real) do
    case real do
      true ->
        task = Task.async(fn -> :ok end)
        task.pid

      false ->
        IEx.Helpers.pid(0, number, 0)
    end
  end
end
