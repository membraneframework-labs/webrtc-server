defmodule Membrane.WebRTC.Server do
  @moduledoc false
  use Application
  use DynamicSupervisor

  def start(_type, _args) do
    {:ok, _} = DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
    registry = Registry.child_spec(keys: :duplicate, name: Server.Registry)
    {:ok, _} = DynamicSupervisor.start_child(Membrane.WebRTC.Server, registry)
  end

  def init(_),
    do:
      {:ok,
       %{
         strategy: :one_for_one,
         intensity: 3,
         max_children: :infinity,
         period: 5,
         extra_arguments: []
       }}
end
