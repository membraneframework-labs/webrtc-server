defmodule Membrane.WebRTC.Server.Peer.Options do
  @moduledoc """
  Structure representing initial peer state. If `Membrane.WebRTC.Server.Peer` is used in Cowboy or
  Plug application, `#{__MODULE__}` should be used as `InitialState` in dispatch rule.

  ## Fields
    - `:module` - Custom module implementing `Membrane.WebRTC.Server.Peer` callbacks.
    - `:custom_options` - Options passed to `c:Membrane.WebRTC.Server.Peer.on_init/3` callback.
    - `:registry` - Registry in which Peer will lookup room. `Membrane.WebRTC.Server.Registry`
    by default.

  """
  @enforce_keys [:module]
  defstruct [:custom_options, registry: Membrane.WebRTC.Server.Registry] ++ @enforce_keys

  @type t :: %__MODULE__{
          module: module(),
          registry: Registry.registry(),
          custom_options: any()
        }
end
