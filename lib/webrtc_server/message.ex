defmodule Membrane.WebRTC.Server.Message do
  @moduledoc """
  Struct defining messages exchanged between peers and rooms.

  ## Data
  Main part of message.

  ## Event
  Topic of the message.

  ### "authenticated" 
  Sent to client after successful peer initialization and joining room. Such messages contain 
  `data.peer_id` field to pass automatically created identifier.

  ### "error"
  Error message sent to client. Such messages contain `data.description` and `data.details`
  fields describing error situation.

  Descriptions used in server API: 

  #### "Invalid message" 
  Sended after JSON decoding error.

  #### "Could not join room"
  Sended after [`on_join/2`](./Membrane.WebRTC.Server.Room.html#c:on_join/2) return 
  `{:error, error}`.

  #### "No such room"
  Sended after no room with name returned by 
  [`parse_request`/1](./Membrane.WebRTC.Server.Peer.html#c:parse_request/1) is registered in
  Membrane.WebRTC.Server.Registry.

  #### "Room closed"
  Broadcasted to all peers in room when process is shutting down.

  ### "joined" 
  Broadcasted by room when peer join a room. Such messages contain `data.peer_id` field
  identifying peer.

  ### "left" 
  Broadcasted by room when peer leave the room. Such messages contain `data.peer_id`
  field identifying peer.

  ## From
  Peer ID of sender.

  ## To
  Peer ID of adresee. If this field is set to "all", all peers in room (expect for the peer
  specified under `from` field) will receive this message. 
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
