defmodule Membrane.WebRTC.Server.Message do
  @moduledoc """
  Struct defining messages exchanged between peers and rooms.
  """
  @enforce_keys [:event]
  defstruct @enforce_keys ++ [:data, :from, :to]

  @type t :: %__MODULE__{
          data: String.t() | map,
          event: String.t(),
          from: String.t(),
          to: String.t()
        }
end
