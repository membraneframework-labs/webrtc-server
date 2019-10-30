## Initialization

For each browser client, there is a process on the server side, which called peer. Peers, grouped
in rooms, are responsible for communication with their clients. Since this communication is based 
on WebSocket, the peer process starts when a client opens a WebSocket connection (probably with 
`new WebSocket(URL)`) and thus, upgrade request is send.

After receiving a request, `t:Membrane.WebRTC.Server.Peer.peer_id/0` will be automatically 
generated. Then a peer should parse the request with 
`c:Membrane.WebRTC.Server.Peer.parse_request/1` callback. Credentials and metadata returned from 
it will be used to create `Membrane.WebRTC.Server.Peer.AuthData` and room's name will be used
 to get a room's PID from `Membrane.Server.WebRTC.Registry`. Then, the state is initialized in 
`c:Membrane.WebRTC.Server.Peer.on_init/3` and authentication is performed with
`Membrane.WebRTC.Server.Peer.AuthData` extracted from the request. Finally, 
WebSocket is initialized.

After successful initialization, the peer will try to join the room with the name returned from 
the `c:Membrane.WebRTC.Server.Peer.parse_request/1`. Authorization (with the same 
`Membrane.WebRTC.Server.Peer.AuthData`) or other checks can be performed in
`c:Membrane.WebRTC.Server.Room.on_join/2` callback. Room automatically broadcast 
`t:Membrane.WebRTC.Server.Message.joined_message/0` to notify other peers about the new one. 
After that, the peer will send `t:Membrane.WebRTC.Server.Message.authenticated_message/0` to the
client to inform about successful initialization.

![](assets/images/init.png)

