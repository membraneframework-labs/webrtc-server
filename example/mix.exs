defmodule Example do
  use Mix.Project

  def project do
    [
      app: :example,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Example.Application, []},
      extra_applications: [:membrane_webrtc_server]
    ]
  end

  defp deps do
    [
      {:membrane_core, "~> 0.3"},
      {:membrane_webrtc_server, path: "../"},
      {:plug, "~> 1.7"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end
end
