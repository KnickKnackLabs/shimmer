defmodule ShimmerCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :shimmer_cli,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    base = [extra_applications: [:logger]]

    # Only set application callback for prod (Burrito binary)
    # Dev/test use Mix tasks which call ShimmerCli.run() directly
    if Mix.env() == :prod do
      Keyword.put(base, :mod, {ShimmerCli, []})
    else
      base
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:burrito, "~> 1.5", only: :prod},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Burrito release configuration for multi-platform builds
  defp releases do
    [
      shimmer: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            linux_x86_64: [os: :linux, cpu: :x86_64],
            linux_arm64: [os: :linux, cpu: :aarch64],
            darwin_arm64: [os: :darwin, cpu: :aarch64]
          ]
        ]
      ]
    ]
  end
end
