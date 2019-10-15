defmodule Membrane.WebRTC.Server.Message do
  @moduledoc """
  Struct defining messages exchanged between peers and rooms.

  ## Fields
    - `:data` - Main part of the message.
    - `:event` - Topic of the message.
    - `:from` - Peer ID of a sender.
    - `:to` - Peer ID of an adresee. If this field is set to "all", all peers in room (expect for
    the peer specified under `from` field) will receive this message. 

  ## Events

  ### `"authenticated"`
  Sent to client after successful peer initialization and joining room. Such messages contain 
  `data.peer_id` field to pass automatically created identifier.

  ### `"error"`
  Error message sent to client. Such messages contain `data.description` and `data.details`
  fields describing reason of an error.

  Descriptions used in server API: 

    - `"Invalid message"` 
    Sent after JSON decoding error.

    - `"Could not join room"`
    Sent after `c:Membrane.WebRTC.Server.Room.on_join/2` return `{:error, error}`.

    - `"Room closed"`
    Broadcasted to all peers in a room when the room's process is shutting down.

  ### `"joined"` 
  Broadcasted by a room when a peer joins the room. Such messages contain `data.peer_id` field
  identifying peer.

  ### `"left"` 
  Broadcasted by a room when a peer leaves the room. Such messages contain `data.peer_id`
  field identifying peer.
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
