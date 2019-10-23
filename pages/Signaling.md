## Signaling

The client communicates with a peer by exchanging JSON messages. These messages should have 
the same fields as `Membrane.WebRTC.Server.Message`, which is used in internal communication.

Every JSON message received from the client will be decoded into `Membrane.WebRTC.Server.Message`
struct. The peer will set `from` field with own peer_id. Then it will send a message to the room, 
where it will be passed to addressee. The addressee and sender are specified in `to` and `from` 
message fields by peer_ids.

The message can be modified or ignored by both peer and room using 
`c:Membrane.WebRTC.Server.Peer.on_receive/3` and `c:Membrane.WebRTC.Server.Room.on_send/2` 
callbacks. The addressee peer, after receiving the message will encode it back to JSON and 
send it to its client.

![](assets/images/signal.png)