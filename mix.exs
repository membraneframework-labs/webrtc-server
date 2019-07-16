defmodule Membrane.WebRTC.Server do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/webrtc-server"

  def project do
    [
      app: :membrane_webrtc_server,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @github_url
    ]
  end

  def application do
    [
      mod: {Membrane.WebRTC.Server.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bunch, "~> 1.0"},
      {:cowboy, "~> 2.6"},
      {:plug, "~> 1.7"},
      {:plug_cowboy, "~> 2.0"},
      {:jason, "~> 1.1"},
      {:membrane_core, "~> 0.3"}
    ]
  end
end
