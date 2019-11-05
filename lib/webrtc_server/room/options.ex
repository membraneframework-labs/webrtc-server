defmodule Membrane.WebRTC.Server.Room.Options do
  @moduledoc """
  Structure representing options that can be passed to 
  `Membrane.WebRTC.Server.Room.start_supervised/1` and `Membrane.WebRTC.Server.Room.start_link/1`.

  ## Fields
    - `custom_options` - Options passed to `c:Membrane.WebRTC.Server.Room.on_init/1` callback.
    - `name` - Name under which room will be registered.
    - `module` - Custom module implementing `Membrane.WebRTC.Server.Room` behaviour. 
    - `registry` - Registry in which room will be registered.
  """

  @enforce_keys [:name]
  defstruct [:custom_options, :registry, module: Membrane.WebRTC.Server.Room.DefaultRoom] ++
              @enforce_keys

  @type custom_options :: any()

  @type t :: %__MODULE__{
          custom_options: custom_options() | nil,
          name: String.t(),
          module: module(),
          registry: Registry.registry()
        }
end
