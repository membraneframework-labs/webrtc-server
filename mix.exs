defmodule Membrane.WebRTC.Server.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/webrtc-server"

  def project do
    [
      app: :membrane_webrtc_server,
      aliases: [docs: ["docs", &copy_images/1]],
      name: "WebRTC Server",
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @github_url,
      docs: docs()
    ]
  end

  defp deps do
    [
      {:uuid, "~> 1.1"},
      {:cowboy, "~> 2.6"},
      {:jason, "~> 1.1"},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:bimap, "~> 1.0"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:bunch, "~> 1.2"}
    ]
  end

  def docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "pages/Guide.md"
      ],
      nest_modules_by_prefix: [
        Membrane.WebRTC.Server
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

  defp copy_images(_) do
    File.cp_r("assets", "doc/assets", fn _source, _destination -> true end)
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_env), do: ["lib"]
end
