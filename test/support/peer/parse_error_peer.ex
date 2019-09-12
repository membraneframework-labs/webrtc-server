defmodule Membrane.WebRTC.Server.Support.ParseErrorPeer do
  @moduledoc false

  use Membrane.WebRTC.Server.Peer

  @impl true
  def parse_auth_request(_request) do
    {:error, :this_is_supposed_to_fail}
  end
end
