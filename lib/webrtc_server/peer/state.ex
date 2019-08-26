defmodule Membrane.WebRTC.Server.Peer.State do
  @moduledoc false

  @enforce_keys [:module, :room, :peer_id, :internal_state]
  defstruct [:room_module] ++ @enforce_keys

  @type t :: %__MODULE__{
          room: String.t(),
          peer_id: String.t(),
          module: module(),
          internal_state: Membrane.WebRTC.Server.Peer.internal_state(),
          room_module: module()
        }
end
