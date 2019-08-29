defmodule Membrane.WebRTC.Server.Support.CustomPeer do
  use Membrane.WebRTC.Server.Peer

  alias Membrane.WebRTC.Server.Message

  @impl true
  def on_init(req, _ctx, _state) do
    {:cowboy_websocket, req, :custom_internal_state, %{idle_timeout: 20}}
  end

  @impl true
  def on_websocket_init(_ctx, _state) do
    state = %{a: :a}
    {:ok, state, :hibernate}
  end

  @impl true
  def on_message(%Message{event: "modify"} = message, _ctx, state) do
    message = %Message{message | data: message.data <> "b"}
    {:ok, message, state}
  end

  @impl true
  def on_message(%Message{event: "ignore"}, _ctx, state) do
    {:ok, state}
  end

  def on_message(%Message{event: "just send it"} = message, _ctx, state) do
    {:ok, message, state}
  end

  def on_message(%Message{event: "change state", data: new_state} = message, _ctx, _state) do
    {:ok, message, new_state}
  end
end
