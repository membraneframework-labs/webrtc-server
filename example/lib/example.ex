defmodule Example.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: :https,
        plug: Example.Router,
        options: [
          dispatch: dispatch(),
          port: 8443,
          ip: {0, 0, 0, 0},
          password: "SECRET",
          otp_app: :example,
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
    [
      {:_,
       [
         {"/websocket/:room/", Membrane.WebRTC.Server.WebSocket, %{module: Example.WebSocket}},
         {:_, Plug.Cowboy.Handler, {Example.Router, []}}
       ]}
    ]
  end
end
