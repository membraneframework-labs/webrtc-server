defmodule Membrane.WebRTC.Server.Peer.AuthData do
  @moduledoc """
  Structure representing data required to perform authentication during peer initialization and
  authorization when a peer is joining a room.

  Metadata and credentials are extracted via `c:Membrane.WebRTC.Server.Peer.parse_request/1` 
  and used in `c:Membrane.WebRTC.Server.Peer.on_init/3` and 
  `c:Membrane.WebRTC.Server.Room.on_join/2`. 

  ## Fields
    - `:peer_id` - A unique identifier created automatically during peer initialization.
    - `:credentials` - Map containing information such as username and password.
    - `:metadata` - Any additional metadata needed to perform authorization and authentication.
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
