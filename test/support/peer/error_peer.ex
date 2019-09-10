defmodule Membrane.WebRTC.Server.Support.ErrorPeer do
  @moduledoc false

  use Membrane.WebRTC.Server.Peer

  @impl true
  def authenticate(_auth_data, _context, _state) do
    {:error, :this_is_supposed_to_fail}
  end
end
