defmodule Membrane.WebRTC.Server.Message do
  @moduledoc """
  Struct defining messages exchanged between peers and rooms.
  """

  @derive Jason.Encoder

  @enforce_keys [:event]
  defstruct @enforce_keys ++ [:data, :from, :to]

  @type t :: %__MODULE__{
          data: String.t() | map | nil,
          event: String.t(),
          from: String.t() | nil,
          to: String.t() | nil
        }
end
