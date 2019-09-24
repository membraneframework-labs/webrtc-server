defmodule Membrane.WebRTC.Server.Peer.AuthData do
  @moduledoc """
  Structure representing data required to perform authorization when Peer is joining Room.

  Metadata and credentials are extracted via `c:Membrane.WebRTC.Server.Peer.parse_request/1`. 
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
