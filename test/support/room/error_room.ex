defmodule Membrane.WebRTC.Server.Support.ErrorRoom do
  @moduledoc false

  use Membrane.WebRTC.Server.Room

  @impl true
  def on_join(_auth_data, state) do
    {{:error, :this_is_supposed_to_fail}, state}
  end
end
