defmodule Example.Simple.Application do
  @moduledoc false
  use Application
  alias Membrane.WebRTC.Server.Peer.Options
  alias Membrane.WebRTC.Server.Room

  @impl true
  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: Application.fetch_env!(:example, :scheme),
        plug: Example.Simple.Router,
        options: [
          dispatch: dispatch(),
          port: Application.fetch_env!(:example, :port),
          ip: Application.fetch_env!(:example, :ip),
          password: Application.fetch_env!(:example, :password),
          otp_app: Application.fetch_env!(:example, :otp_app),
          keyfile: Application.fetch_env!(:example, :keyfile),
          certfile: Application.fetch_env!(:example, :certfile)
        ]
      )
    ]

    Room.start_supervised("room", Example.Simple.Room)

    opts = [strategy: :one_for_one, name: Example.Simple.Application]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    options = %Options{module: Example.Simple.Peer}

    [
      {:_,
       [
         {"/server/[:room]/[:username]/[:password]/", Membrane.WebRTC.Server.Peer, options},
         {:_, Plug.Cowboy.Handler, {Example.Simple.Router, []}}
       ]}
    ]
  end
end
