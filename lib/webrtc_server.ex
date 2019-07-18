defmodule Membrane.WebRTC.Server do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      Registry.child_spec(
        keys: :duplicate,
        name: Server.Registry
      )
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
