defmodule Membrane.WebRTC.Server.Support.InitErrorPeer do
  @moduledoc false

  use Membrane.WebRTC.Server.Peer

  @impl true
  def on_init(_auth_data, _context, _state) do
    {:error, :this_is_supposed_to_fail}
  end
end