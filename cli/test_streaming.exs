# Test script to diagnose streaming behavior
# Run with: elixir test_streaming.exs

defmodule StreamTest do
  def run do
    IO.puts("Starting streaming test at #{DateTime.utc_now()}")
    IO.puts("---")

    cmd = "echo | claude -p 'count from 1 to 5, one number per line, with a brief pause between each' --output-format stream-json --verbose --include-partial-messages --dangerously-skip-permissions"

    port = Port.open({:spawn, cmd}, [:binary, :exit_status, :stderr_to_stdout])
    stream_output(port)
  end

  defp stream_output(port) do
    receive do
      {^port, {:data, data}} ->
        timestamp = DateTime.utc_now() |> DateTime.to_time() |> Time.to_string()

        data
        |> String.split("\n", trim: true)
        |> Enum.each(fn line ->
          case Jason.decode(line) do
            {:ok, decoded} ->
              type = Map.get(decoded, "type", "unknown")
              # Show full structure for debugging
              IO.puts("[#{timestamp}] #{type}: #{inspect(decoded, limit: 5, pretty: false) |> String.slice(0, 200)}")

            {:error, _} ->
              IO.puts("[#{timestamp}] RAW: #{String.slice(line, 0, 100)}")
          end
        end)

        stream_output(port)

      {^port, {:exit_status, status}} ->
        IO.puts("---")
        IO.puts("Exited with status #{status} at #{DateTime.utc_now()}")
    end
  end
end

StreamTest.run()
