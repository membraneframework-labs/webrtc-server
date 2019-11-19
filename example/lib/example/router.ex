defmodule Example.Router do
  use Plug.Router
  require EEx
  alias Example.UserManager
  alias Example.UserManager.Guardian

  plug(Plug.Static,
    at: "/",
    from: :example
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    if Guardian.Plug.authenticated?(conn) do
      videochat(conn)
    else
      send_file(conn, 200, "priv/static/index.html")
    end
  end

  post "/" do
    {:ok, body, conn} = read_body(conn)

    case URI.decode_query(body) do
      %{"username" => username, "password" => password} ->
        UserManager.authenticate_user(username, password)
        |> login_result(conn)

      _ ->
        :not_ok
    end
  end

  post "/logout" do
    conn
    |> Guardian.Plug.sign_out()
    |> Guardian.Plug.clear_remember_me()
    |> redirect("/")
  end

  match _ do
    send_resp(conn, 404, "404")
  end

  defp login_result({:error, _error}, conn) do
    redirect(conn, "/")
  end

  defp login_result({:ok, user}, conn) do
    conn
    |> Guardian.Plug.sign_in(user)
    |> Guardian.Plug.remember_me(user)
    |> videochat()
  end

  defp videochat(conn) do
    send_file(conn, 200, "priv/static/html/video_chat.html")
  end

  defp redirect(conn, to) do
    conn
    |> put_resp_header("location", to)
    |> send_resp(conn.status || 302, "text/html")
  end
end
