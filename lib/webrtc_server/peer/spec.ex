defmodule Membrane.WebRTC.Server.Peer.Spec do
  @enforce_keys [:module]
  defstruct [:custom_spec, :room_module] ++ @enforce_keys

  @type t :: %__MODULE__{
          module: module() | nil,
          custom_spec: any,
          room_module: module() | nil
        }
end
