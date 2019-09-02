defmodule Membrane.WebRTC.Server.Support.RoomHelper do
  @moduledoc false

  def generate_pid(_number, true),
    do: spawn(fn -> :ok end)

  def generate_pid(number, false),
    do: IEx.Helpers.pid(0, number, 0)
end
