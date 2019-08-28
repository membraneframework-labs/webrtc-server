defmodule Membrane.WebRTC.Server.MixProject do
  use Mix.Project

  @version "1.0.0"
  @github_url "https://github.com/membraneframework/webrtc-server"

  def project do
    [
      app: :membrane_webrtc_server,
      name: "WebRTC Server",
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @github_url,
      docs: docs()
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 2.6"},
      {:jason, "~> 1.1"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:bimap, "~> 1.0"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:bunch, "~> 1.2"}
    ]
  end

  def docs do
    [
      main: "readme",
      extras: ["README.md"],
      nest_modules_by_prefix: [
        Membrane.WebRTC.Server.Peer,
        Membrane.WebRTC.Server.Room,
        Membrane.WebRTC.Server.Message
      ],
      groups_for_modules: [
        Peer: [~r/^Membrane.WebRTC.Server.Peer.*/],
        Room: [~r/^Membrane.WebRTC.Server.Room.*/],
        Message: [~r/^Membrane.WebRTC.Server.Message.*/]
      ]
    ]
  end

  def application do
    [
      mod: {Membrane.WebRTC.Server, []},
      extra_applications: []
    ]
  end
end
