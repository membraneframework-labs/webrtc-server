defmodule Membrane.WebRTC.Server.Support.CustomPeer do
  @moduledoc false

  use Membrane.WebRTC.Server.Peer

  alias Membrane.WebRTC.Server.Message

  @impl true
  def on_init(_ctx, _state) do
    {:ok, %{idle_timeout: 20}, :custom_internal_state}
  end

  @impl true
  def on_send(%Message{event: "modify"} = message, _ctx, state) do
    message = %Message{message | data: message.data <> "b"}
    {:ok, message, state}
  end

  @impl true
  def on_send(%Message{event: "ignore"}, _ctx, state) do
    {:ok, state}
  end

  def on_send(%Message{event: "just send it"} = message, _ctx, state) do
    {:ok, message, state}
  end

  def on_send(%Message{event: "change state", data: new_state} = message, _ctx, _state) do
    {:ok, message, new_state}
  end
end
