defmodule Membrane.WebRTC.Server.Support.MockPeer do
  @moduledoc false

  use Membrane.WebRTC.Server.Peer

  @impl true
  def parse_request(_request) do
    {:ok, %{}, nil, "room"}
  end
end
