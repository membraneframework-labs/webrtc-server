defmodule Example.Room do
  @moduledoc false
  use Membrane.WebRTC.Server.Room

  @impl true
  def on_join(auth_data, state) do
    username = auth_data.credentials.username
    password = auth_data.credentials.password

    if username == "JohnSmith" and password == "1234" do
      {:ok, state}
    else
      {{:error, :wrong_credentials}, state}
    end
  end
end
