defmodule Membrane.WebRTC.Server.Peer.Context do
  @enforce_keys [:room, :peer_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          room: String.t(),
          peer_id: String.t()
        }
end
