defmodule Cli.MixProject do
  use Mix.Project

  def project do
    [
      app: :cli,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    base = [extra_applications: [:logger]]

    # Only set application callback for prod (Burrito binary)
    # Dev/test use Mix tasks which call Cli.run() directly
    if Mix.env() == :prod do
      Keyword.put(base, :mod, {Cli, []})
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
end
