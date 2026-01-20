defmodule Shimmer.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  # Umbrella-level dependencies (shared across all apps)
  # Most dependencies stay in individual apps; only truly shared deps go here
  defp deps do
    []
  end

  # Burrito release configuration for multi-platform builds
  # Releases are configured at umbrella level
  defp releases do
    [
      shimmer: [
        applications: [cli: :permanent],
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
