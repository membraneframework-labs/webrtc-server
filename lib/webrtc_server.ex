defmodule Membrane.WebRTC.Server do
  @moduledoc false
  use Application

  defmodule RoomSupervisor do
    use DynamicSupervisor
    @moduledoc false
    def init(_) do
      {:ok,
       %{
         strategy: :one_for_one,
         intensity: 3,
         max_children: :infinity,
         period: 5,
         extra_arguments: []
       }}
    end

    def start_link(_arg),
      do: DynamicSupervisor.start_link(__MODULE__, :ok, name: Server.RoomSupervisor)
  end

  def start(_type, _args) do
    children = [
      Registry.child_spec(keys: :unique, name: Membrane.WebRTC.Server.Registry),
      Membrane.WebRTC.Server.RoomSupervisor
    ]

    options = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, options)
  end
end
