defmodule Membrane.WebRTC.Server.IntegrationTest do
  use ExUnit.Case, async: false

  alias Membrane.WebRTC.Server.{Peer, Room, Peer.State, Message}

  @module Membrane.WebRTC.Server.Peer

  defmodule MockSocket do
    use Peer
  end

  setup_all do
    Application.start(:debug)
    Registry.start_link(keys: :unique, name: Server.Registry)
    Logger.configure(level: :error)
  end

  setup do
    child_spec = {Room, %{name: "room", module: Membrane.WebRTC.Server.Peer.DefaultRoom}}
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
      {:ok, correct_message} =
        Jason.encode(%{"to" => "peer_1", "data" => %{}, "event" => "event"})

      @module.websocket_handle({:text, correct_message}, ctx[:peer_state])

      assert_received %Membrane.WebRTC.Server.Message{
        data: %{},
        event: "event",
        from: "peer_10",
        to: "peer_1"
      }
    end
  end

  describe "handle terminate" do
    test "should return :ok and receive message about leaving room by peer_10", ctx do
      assert @module.terminate(:normal, %{}, ctx[:peer_state]) == :ok
      assert_receive %Message{data: %{peer_id: "peer10"}, event: :left}
    end
  end

  def insert_peers(number_of_peers, room, real \\ false)
  def insert_peers(1, room, real), do: Room.join(room, "peer_1", self())

  def insert_peers(n, room, real) when n > 1 do
    Room.join(room, "peer_1", self())

    2..n
    |> Enum.map(fn num ->
      Room.join(
        room,
        "peer" <> to_string(num),
        generate_pid(num, real)
      )
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
        task = Task.async(fn -> :ok end)
        task.pid

      false ->
        IEx.Helpers.pid(0, number, 0)
    end
  end
end
