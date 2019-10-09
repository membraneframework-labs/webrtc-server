defmodule Membrane.WebRTC.Server.Peer.AuthData do
  @moduledoc """
  Structure representing data required to perform authentication during peer initialization and
  authorization when peer is joining room.

  Metadata and credentials are extracted via `c:Membrane.WebRTC.Server.Peer.parse_request/1` 
  and used in `c:Membrane.WebRTC.Server.Peer.on_init/3` and 
  `c:Membrane.WebRTC.Server.Room.on_join/2`. 

  ## Peer ID
  Unique identifier created automatically during peer initialization.

  ## Credentials
  Map containing informations such as username and password.

  ## Metadata
  Any additional metadata needed to perform authorization and authentication.
  """
  @derive {Inspect, only: [:peer_id]}
  @enforce_keys [:peer_id, :credentials]
  defstruct @enforce_keys ++ [:metadata]

  @type t :: %__MODULE__{
          peer_id: String.t(),
          credentials: map(),
          metadata: any()
        }
end
