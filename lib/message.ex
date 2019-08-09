defmodule Membrane.WebRTC.Server.Message do
  @enforce_keys [:event]
  defstruct @enforce_keys ++ [:data, :from, :to]

  @type t :: %__MODULE__{
          data: String.t() | map,
          event: String.t(),
          from: String.t(),
          to: String.t()
        }
end
