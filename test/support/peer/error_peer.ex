defmodule Membrane.WebRTC.Server.Support.ErrorPeer do
  use Membrane.WebRTC.Server.Peer

  @impl true
  def authenticate(_req, _options) do
    {:error, :this_is_supposed_to_fail}
  end
end
