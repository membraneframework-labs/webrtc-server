defmodule Membrane.WebRTC.Server.Peer.Options do
  @moduledoc """
  Structure representing initial peer options passed as `state` to `cowboy_websocket.init/1` callback.
  Value under key `custom_options` will be passed as options to `c:Membrane.WebRTC.Server.Peer.authenticate/2` callback.
  """
  @enforce_keys [:module]
  defstruct [:custom_options, room_module: Membrane.WebRTC.Server.Peer.DefaultRoom] ++
              @enforce_keys

  @type t :: %__MODULE__{
          module: module(),
          custom_options: any,
          room_module: module()
        }
end
