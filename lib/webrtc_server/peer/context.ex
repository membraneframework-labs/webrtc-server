defmodule Membrane.WebRTC.Server.Peer.Context do
  @moduledoc """
  Structure representing state of `Membrane.WebRTC.Server.Peer` passed to every (but `c:Membrane.WebRTC.Server.Peer.authenticate/2`) callback.
  """

  @enforce_keys [:room, :peer_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          room: String.t(),
          peer_id: String.t()
        }
end
