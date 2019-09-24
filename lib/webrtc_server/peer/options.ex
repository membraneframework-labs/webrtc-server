defmodule Membrane.WebRTC.Server.Peer.Options do
  @moduledoc """
  Structure representing initial peer options passed as `state` to
  [`cowboy_websocket.init`](https://ninenines.eu/docs/en/cowboy/2.6/manual/cowboy_websocket/)
  callback.

  ## Module
  Custom module implementing Membrane.WebRTC.Server.Peer callbacks.

  ## Custom Options
  Options passed to `c:Membrane.WebRTC.Server.Peer.on_init/2` callback.
  """
  @enforce_keys [:module]
  defstruct [:custom_options] ++ @enforce_keys

  @type t :: %__MODULE__{
          module: module(),
          custom_options: any
        }
end
