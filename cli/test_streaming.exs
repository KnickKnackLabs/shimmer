# Test script to diagnose streaming behavior
# Run with: mix run test_streaming.exs

defmodule StreamTest do
  def run do
    IO.puts("Starting streaming test at #{DateTime.utc_now()}")
    IO.puts("---")

    cmd = "echo | claude -p 'count from 1 to 3, waiting 1 second between each number' --output-format stream-json --verbose --include-partial-messages --dangerously-skip-permissions"

    port = Port.open({:spawn, cmd}, [:binary, :exit_status, :stderr_to_stdout])
    stream_output(port, "")
  end

  defp stream_output(port, buffer) do
    receive do
      {^port, {:data, data}} ->
        timestamp = DateTime.utc_now() |> DateTime.to_time() |> Time.to_string()
        combined = buffer <> data
        lines = String.split(combined, "\n")

        # Last element may be incomplete - keep it as new buffer
        {complete_lines, [new_buffer]} = Enum.split(lines, -1)

        complete_lines
        |> Enum.reject(&(&1 == ""))
        |> Enum.each(fn line ->
          case Jason.decode(line) do
            {:ok, decoded} ->
              type = Map.get(decoded, "type", "unknown")

              # Show more detail for interesting events
              detail = case decoded do
                %{"type" => "stream_event", "event" => %{"delta" => %{"text" => text}}} ->
                  "TEXT: #{inspect(text)}"
                %{"type" => "stream_event", "event" => %{"delta" => %{"partial_json" => json}}} ->
                  "TOOL_INPUT: #{String.slice(json, 0, 80)}"
                %{"type" => "stream_event", "event" => %{"content_block" => %{"type" => "tool_use", "name" => name}}} ->
                  "TOOL_START: #{name}"
                %{"type" => "stream_event", "event" => %{"type" => event_type}} ->
                  "EVENT: #{event_type}"
                _ ->
                  inspect(decoded, limit: 3, pretty: false) |> String.slice(0, 150)
              end

              IO.puts("[#{timestamp}] #{type}: #{detail}")

            {:error, _} ->
              IO.puts("[#{timestamp}] RAW: #{String.slice(line, 0, 100)}")
          end
        end)

        stream_output(port, new_buffer)

      {^port, {:exit_status, status}} ->
        IO.puts("---")
        IO.puts("Exited with status #{status} at #{DateTime.utc_now()}")
    end
  end
end

StreamTest.run()
