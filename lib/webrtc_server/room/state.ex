defmodule Membrane.WebRTC.Server.Room.State do
  @moduledoc false

  @enforce_keys [:module, :peers]
  defstruct [:internal_state] ++ @enforce_keys

  @type t :: %__MODULE__{
          peers: BiMap.t(),
          module: module(),
          internal_state: Membrane.WebRTC.Server.Room.internal_state()
        }
end
