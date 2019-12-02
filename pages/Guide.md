# Guide
## Peer initialization

For each browser client, there is a process on the server side, which is called peer. Peers, 
grouped in rooms, are responsible for communication with their clients. Since this communication 
is based on WebSocket, the peer process starts when a client opens a WebSocket connection 
(probably with `new WebSocket(URL)`) and thus, upgrade request is send.

After receiving a request, `t:Membrane.WebRTC.Server.Peer.peer_id/0` will be automatically 
generated. Then a peer should parse the request with 
`c:Membrane.WebRTC.Server.Peer.parse_request/1` callback. Credentials and metadata returned from 
it will be used to create `Membrane.WebRTC.Server.Peer.AuthData` and room's name will be used
 to get a room's PID from the registry (specified in `Membrane.WebRTC.Options`. Then, the state is 
initialized in `c:Membrane.WebRTC.Server.Peer.on_init/3` and authentication is performed with
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

## Signalling

The client communicates with a peer by exchanging JSON messages. These messages should have 
the same fields as the `Membrane.WebRTC.Server.Message`, which is used in internal communication. 
Other fields of JSON will be lost in decoding.

Every JSON received from the client will be decoded into the `Membrane.WebRTC.Server.Message` 
struct. The peer will set `:from` field with own peer_id. Then it will send a message to the room, 
where it will be forwarded to the addressees. The addressees and sender are specified in 
`to` and `from` message fields by peer_ids.

The message can be modified or ignored by both peer and room using 
`c:Membrane.WebRTC.Server.Peer.on_receive/3` and `c:Membrane.WebRTC.Server.Room.on_forward/2` 
callbacks. The addressee peer, after receiving the message will encode it back to JSON 
and send it to its client.

![](assets/images/signal.png)

# Creating example application
This guide focus on writing simple WebRTC application based on Plug.

Complete source code can be found
[here](https://github.com/membraneframework/webrtc-server/tree/master/examples/simple).

## Setting up a project
Create a new mix project with
```
$ mix new server --module Server
```

To create a server, we have to add Membrane WebRTC Server to dependencies. Add this line 
to the `deps` in `mix.exs`.

```
{:membrane_webrtc_server, "~> 0.1"}
```

We will also use `Plug` (i.a. to set up routing) and `Jason` (to parse credentials received from
the app:
```
{:jason, "~> 1.1"},
{:plug, "~> 1.7"},
{:plug_cowboy, "~> 2.0"}
```

## Creating a peer module
Inside `lib/server` folder create a new module which uses `Membrane.WebRTC.Server.Peer`.
```elixir
defmodule Server.Peer
  use Membrane.WebRTC.Server.Peer

  ...
```

## Implementing `parse_request` callback
Before initialization of peer, an authentication request is parsed in `parse_request`. This function
receives the request and should return a tuple containing `:ok` atom, credentials, metadata and name of
the room peer wants to join.

```elixir
@impl true
def parse_request(request) do
  ...

  {:ok, credentials, metadata, room_name}
end
```

Let's assume that JS client will specify room in URL binding. We can get the name with the following
function:

```elixir
defp get_room_name(request) do
  room_name = :cowboy_req.binding(:room, request)

  if room_name == :undefined do
    {:error, :no_room_name_bound_in_url}
  else
    {:ok, room_name}
  end
end
```

Easy way to send credentials with WebSocket upgrade request is to include them in a cookie. After
retrieving them, we should decode them with `Jason.decode`.

```elixir
defp get_credentials(request) do
  case :cowboy_req.parse_cookies(request) |> List.keyfind("credentials", 0) do
    {"credentials", json} ->
      Jason.decode(json)

    _ ->
      {:error, :no_credentials_passed}
end
```

Now we can finish implementing `parse_request`. We have our room name, credentials and we don't 
need metadata for this request, so we will return `nil` instead of it. The finished function should
look like something like this:

```elixir
@impl true
def parse_request(request) do
  with {:ok, room_name} <- get_room_name(request),
       {:ok, credentials} <- get_credentials(request) do
    {:ok, credentials, nil, room_name}
  end
end
```

Please notice that storing non-hashed credentials in cookie is unsafe (since they are available as
plain text). Example of more sophisticated authentication based on Guardian can be found 
[here](https://github.com/membraneframework/webrtc-server/tree/master/examples/auth).

## Authentication
Authentication happens before WebSocket initialization. We can perform it in `on_init` callback, 
for example: 

```elixir
@impl true
def on_init(_context, auth_data, _options) do
  username = Map.get(auth_data.credentials, "username")
  password = Map.get(auth_data.credentials, "password")

  if username == "USERNAME" and password == "PASSWORD" do
    {:ok, %{}}
  else
    {:error, :wrong_credentials}
  end
end
```

The return value (in case of successful authentication) contains an empty map, which is a new state 
for the peer.

## Implementing room
Since mesh WebRTC can't scale to a large number of participants, we will create Room which will
block not let more than 2 peers in.

Inside `lib/server/` folder create a new module which uses `Membrane.WebRTC.Server.Room`.

```elixir
defmodule Example.Simple.Room do
  use Membrane.WebRTC.Server.Room
```

Starting room process will get the maximal number of peers from initial options 
(value under `:custom_options` field in `Membrane.WebRTC.Server.Room.Options`).
We can specify that behaviour in `handle_init` implementation.

```elixir
@impl true
def on_init(options) do
  {:ok, %{number_of_peers: 0, max_peers: options.max_peers}}
end
```

So, as you can see, `options` will be map with field `:max_peers`.

The return value contains a map (new state of our room) with the current number of peers and the maximal 
number of peers. Starting room is empty, so `:number_of_peers` equals 0.

Every time peer will join the room we must check, if we surpass allowed number. If not,
the room must increment it. We'll specify that behaviour in `on_join` callback.

```elixir
@impl true
def on_join(_auth_data, state) do
  current_number = state.number_of_peers

  if current_number < state.max_peers do
    {:ok, Map.put(state, :number_of_peers, current_number + 1)}
  else
    {{:error, :room_is_full}, state}
  end
end
```

When this function return error, an error message will be sent to the client.

Of course, we also have to decrement the number of peers if some peer leaves.

```elixir
@impl true
def on_leave(_peer_id, state) do
  {:ok, Map.put(state, :number_of_peers, state.number_of_peers - 1)}
end
```

To sum up, the whole file should look like this:

```elixir
defmodule Server.Room do
  use Membrane.WebRTC.Server.Room

  @impl true
  def on_init(options) do
    {:ok, %{number_of_peers: 0, max_peers: options.max_peers}}
  end

  @impl true
  def on_join(_auth_data, state) do
    current_number = state.number_of_peers

    if current_number < state.max_peers do
      {:ok, Map.put(state, :number_of_peers, current_number + 1)}
    else
      {{:error, :room_is_full}, state}
    end
  end

  @impl true
  def on_leave(_peer_id, state) do
    {:ok, Map.put(state, :number_of_peers, state.number_of_peers - 1)}
  end
end
```

## Configuring router
As mentioned before, this application uses `Plug` to set up routing. Let's configure our router:

```
defmodule Example.Simple.Router do
  use Plug.Router

  plug(Plug.Static,
    at: "/",
    from: :example_simple
  )

  plug(:match)
  plug(:dispatch)

  get "/:room" do
    send_file(conn, 200, "priv/static/html/index.html")
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
```

As you can see, the URL will specify room for the client.

## Generating key and certificate
Since the application uses HTTPS, certificate and key are needed to run it. You generate them with

```
$ openssl req -newkey rsa:2048 -nodes -keyout priv/certs/key.pem -x509 -days 365 -out priv/certs/certificate.pem
```

Note that this certificate is not validated and thus may cause warnings in the browser.

## Dispatching and starting the application 
Now, with ready Room, Peer and Router, we can configure how our application is started. Inside 
`lib/server.ex` create module `Server`, which uses `Application`.

```elixir
defmodule Server do
  use Application
  alias Membrane.WebRTC.Server.Peer
  alias Membrane.WebRTC.Server.Room
    
  ...
```

First of all, we have to configure our `dispatch` function. It will specify routes rules. Let's 
assume that a WebSocket upgrade request will be given at `/socket/[:room]`. Our Router will take 
care of every other request.

```elixir
defp dispatch do
  peer_options = %Peer.Options{module: Server.Peer, registry: Server.Registry}
  
  [
    {:_,
     [
       {"/socket/[:room]/", Membrane.WebRTC.Server.Peer, peer_options},
       {:_, Plug.Cowboy.Handler, {Example.Simple.Router, []}}
     ]}
  ]
end
```

As you can see, we also scecify options for starting peer process. Peer uses `Server.Registry`
which we'll start in a moment. 

We have to implement a `start` function, in which we will start other processes.

```elixir
@impl true
def start(_type, _args) do
  options = [strategy: :one_for_one, name: Server]
  children = [
    ...
  ]

  Supervisor.start_link(children, options)
end
```

Inside the `children` list, we will specify three workers: `Server.Registry`, `Plug.Cowboy` and
`Server.Room`. Please note that room must be started after the registry (because room uses it to 
registry itself). 

```elixir
children = [
  Registry.child_spec(keys: :unique, name: Example.Simple.Registry),
  Plug.Cowboy.child_spec(
    scheme: Application.fetch_env!(:server, :scheme),
    plug: Example.Simple.Router,
    options: [
      dispatch: dispatch(),
      port: 8443,
      ip: {0, 0, 0, 0},
      password: "PASSWORD",
      otp_app: :example_simple,
      keyfile: "priv/certs/key.pem",
      certfile: "priv/certs/certificate.pem"
    ]
  ),
  Supervisor.child_spec(
    {Room,
     %Room.Options{
       name: "room",
       module: Server.Room,
       registry: Server.Registry,
       custom_options: %{max_peers: 2}
     }},
    id: :room
  )
]
```

If you want to start room after application is started (i.e. every time peer wants to join 
non-existing room), you can use `Room.start_supervised` function.

We can also add other rooms, with different names and/or maximal numbers of peers.

```elixir
...

Supervisor.child_spec(
  {Room,
   %Room.Options{
     name: "other",
     module: Server.Room,
     registry: Server.Registry,
     custom_options: %{max_peers: 4}
   }},
  id: :other_room
)

...
```
