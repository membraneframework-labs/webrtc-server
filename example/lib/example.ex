defmodule Example.Application do
  @moduledoc false
  use Application
  alias Membrane.WebRTC.Server.Peer.Options
  alias Membrane.WebRTC.Server.Room

  @impl true
  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        # WebRTC over HTTP is possible, however Chrome and Firefox require HTTPS for getUserMedia()
        scheme: :https,
        plug: Example.Router,
        options: [
          dispatch: dispatch(),
          port: Application.fetch_env!(:example, :port),
          ip: Application.fetch_env!(:example, :ip),
          password: Application.fetch_env!(:example, :password),
          otp_app: :example,
          keyfile: Application.fetch_env!(:example, :keyfile),
          certfile: Application.fetch_env!(:example, :certfile)
        ]
      ),
      Room.child_spec(%{name: "room", module: Example.Room})
    ]

    opts = [strategy: :one_for_one, name: Example.Application]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(_state) do
    :ok
  end

  defp dispatch do
    options = %Options{module: Example.Peer, custom_options: %{}}

    [
      {:_,
       [
         {"/websocket/[:room]/[:username]/[:password]/", Membrane.WebRTC.Server.Peer, options},
         {:_, Plug.Cowboy.Handler, {Example.Router, []}}
       ]}
    ]
  end
end
