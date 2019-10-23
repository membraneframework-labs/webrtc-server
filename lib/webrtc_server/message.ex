defmodule Membrane.WebRTC.Server.Message do
  @moduledoc """
  Struct defining messages exchanged between peers and rooms.

  ## Fields
    - `:data` - Main part of the message. Value under that field MUST BE encodable by 
  `Jason.Encoder`.
    - `:event` - Topic of the message.
    - `:from` - Peer ID of a sender.
    - `:to` - Peer ID of an adressee. If this field is set to `"all"`, message will be broadcasted:
    all peers in the room (expect for the peer specified under `from` field) will receive this 
    message. 

  ## Messages in Server API
  Messages used by `Membrane.WebRTC.Server.Room` and `Membrane.WebRTC.Server.Peer` modules:
    - `t:authenticated_message/0`
    - `t:error_message/0`
    - `t:joined_message/0`
    - `t:left_message/0`

  Note that these are NOT the only types of Messages, that can be used in applications. 
  Custom types can be defined with `t:t/1`.
  """

  @derive Jason.Encoder
  alias Membrane.WebRTC.Server.Room

  @enforce_keys [:event]
  defstruct @enforce_keys ++ [:data, :from, :to]

  @type t :: %__MODULE__{
          data: Jason.Encoder.t() | nil,
          event: String.t(),
          from: String.t() | nil,
          to: String.t() | nil
        }

  @typedoc """
  Type prepared for defining custom `Membrane.WebRTC.Server.Message`.

  `d` MUST BE encodable by `Jason.Encoder`.  
  """
  @type t(d) :: %__MODULE__{
          data: d,
          event: String.t(),
          from: String.t() | nil,
          to: String.t()
        }

  @typedoc """
  Sent after peer successfully initialize and join the room. 

  `:event` is set to `"authenticated"`.

  ## Data fields
    - `:peer_id` - Identifier of the peer, that has joined the room.
  """
  @type authenticated_message ::
          %__MODULE__{
            data: %{
              peer_id: Room.peer_id()
            },
            event: String.t(),
            from: nil,
            to: String.t()
          }

  @typedoc """
  Error message. 

  `:event` is set to `"error"`.

  ## Data fields
    - `:description`- Topic of error message.
    - `:details` - Details of error. 

  ## Descriptions used in server API
    - `"Invalid message"` 
    Sent to client after JSON decoding error.

    - `"Could not join room"`
    Sent to client after `c:Membrane.WebRTC.Server.Room.on_join/2` return `{:error, error}`.

    - `"Room closed"`
    Broadcasted to all peers in a room when the room's process is shutting down.
  """
  @type error_message :: %__MODULE__{
          data: %{
            description: String.t(),
            details: Jason.Encoder.t()
          },
          event: String.t(),
          from: nil,
          to: Room.peer_id()
        }

  @typedoc """
  Broadcasted by a room when a peer joins the room. 

  `:event` is set to `"joined"`.  
  `:to` is set to `"all"`.

  ## Data fields
    - `:peer_id` - Identifier of the peer, that has joined the room.
  """
  @type joined_message :: %__MODULE__{
          data: %{peer_id: Room.peer_id()},
          event: String.t(),
          from: nil,
          to: String.t()
        }

  @typedoc """
  Broadcasted by a room when a peer leaves the room. 

  `:event` is set to "left".

  ## Data fields:
    - `:peer_id` - Identifier of the peer, that has left the room.
  """
  @type left_message :: %__MODULE__{
          data: %{peer_id: Room.peer_id()},
          event: String.t(),
          from: nil,
          to: String.t()
        }
end
