defmodule Membrane.WebRTC.Server.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: :https,
        plug: Membrane.WebRTC.Server.Router,
        options: [
          dispatch: dispatch(),
          port: 8443,
          ip: {0, 0, 0, 0},
          password: "SECRET",
          otp_app: :membrane_webrtc_server,
          keyfile: "priv/certs/key.pem",
          certfile: "priv/certs/certificate.pem"
        ]
      ),
      Registry.child_spec(
        keys: :duplicate,
        name: Registry.Server
      )
    ]

    opts = [strategy: :one_for_one, name: Membrane.WebRTC.Server.Application]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(_state) do
    :ok
  end

  defp dispatch do
    [
      {:_,
       [
         {"/websocket/[...]", Membrane.WebRTC.Server.WebSocket, []},
         {:_, Plug.Cowboy.Handler, {Membrane.WebRTC.Server.Router, []}}
       ]}
    ]
  end
end
