defmodule Membrane.WebRTC.Server.Peer.Options do
  @moduledoc """
  Structure representing initial peer state. If `Membrane.WebRTC.Server.Peer` is used in Cowboy or
  Plug application, `#{__MODULE__}` should be used as `InitialState` in dispatch rule.

  ## Module
  Custom module implementing `Membrane.WebRTC.Server.Peer` callbacks.

  ## Custom Options
  Options passed to `c:Membrane.WebRTC.Server.Peer.on_init/3` callback.
  """
  @enforce_keys [:module]
  defstruct [:custom_options] ++ @enforce_keys

  @type t :: %__MODULE__{
          module: module(),
          custom_options: any
        }
end
