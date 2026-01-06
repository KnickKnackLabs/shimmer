defmodule Mix.Tasks.Shimmer do
  @shortdoc "Run the Shimmer CLI"
  @moduledoc """
  Runs the Shimmer CLI with the provided arguments.

  This task is used in development and CI to run the CLI without building
  an escript. Unlike escript, Mix tasks properly support `:code.priv_dir/1`.

  ## Usage

      mix shimmer --agent <name> --timeout <seconds> [options] <message>

  ## Examples

      mix shimmer --agent quick --timeout 300 "Fix the bug in cli.ex"
      mix shimmer --agent brownie --timeout 600 --job probe "Explore the codebase"

  """
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    args |> Cli.run() |> System.halt()
  end
end
