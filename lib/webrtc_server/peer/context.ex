defmodule Membrane.WebRTC.Server.Peer.Context do
  @moduledoc """
  Structure representing a state of peer passed to every
  (but `c:Membrane.WebRTC.Server.Peer.parse_request/1`) callback.

  ## Room
  Name of room process 

  ## Peer ID
  Unique identifier created automatically during peer initialization.
  """

  @enforce_keys [:room, :peer_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          room: String.t(),
          peer_id: String.t()
        }
end
