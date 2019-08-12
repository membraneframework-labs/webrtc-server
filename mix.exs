defmodule Membrane.WebRTC.Server.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/webrtc-server"

  def project do
    [
      app: :membrane_webrtc_server,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @github_url
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 2.6"},
      {:jason, "~> 1.1"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:bimap, "~> 1.0"}
    ]
  end

  def application do
    [
      mod: {Membrane.WebRTC.Server, []},
      extra_applications: []
    ]
  end
end
