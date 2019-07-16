defmodule Membrane.WebRTC.Server.Router do
  use Plug.Router
  require EEx

  plug(Plug.Static,
    at: "/",
    from: :membrane_webrtc_server
  )

  plug(:match)
  plug(:dispatch)

  EEx.function_from_file(:defp, :application_html, "priv/static/index.html", [])

  get "/" do
    send_file(conn, 200, "priv/static/index.html")
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
