defmodule Example.Application do
  @moduledoc false
  use Application
  alias Membrane.WebRTC.Server.Peer.Options

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        # WebRTC over HTTP is possible, however Chrome and Firefox require HTTPS for getUserMedia()
        scheme: :https,
        plug: Example.Router,
        options: [
          dispatch: dispatch(),
          port: 8443,
          ip: {0, 0, 0, 0},
          password: "SECRET",
          otp_app: :example,
          # Attach your SSL certificate and key files here
          keyfile: "priv/certs/key.pem",
          certfile: "priv/certs/certificate.pem"
        ]
      )
    ]

    opts = [strategy: :one_for_one, name: Example.Application]
    Supervisor.start_link(children, opts)
  end

  def stop(_state) do
    :ok
  end

  defp dispatch do
    options = %Options{module: Example.Peer, custom_options: %{}}

    [
      {:_,
       [
         {"/websocket/:room/", Membrane.WebRTC.Server.Peer, options},
         {:_, Plug.Cowboy.Handler, {Example.Router, []}}
       ]}
    ]
  end
end
