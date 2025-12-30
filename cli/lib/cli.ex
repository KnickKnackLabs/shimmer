defmodule Cli do
  @timeout_seconds 240  # 4 minutes, leaves 1 minute buffer before GitHub's 5-minute timeout

  def main(args) do
    message = Enum.join(args, " ")
    IO.puts("Running at: #{DateTime.utc_now()}")
    IO.puts("Message: #{message}")
    IO.puts("Timeout: #{@timeout_seconds}s")
    IO.puts("---")

    if message != "" do
      escaped_message = String.replace(message, "'", "'\\''")
      # Pipe empty stdin to close it, use stream-json with --verbose and --include-partial-messages for real streaming
      cmd = "echo | timeout #{@timeout_seconds} claude -p '#{escaped_message}' --output-format stream-json --verbose --include-partial-messages --dangerously-skip-permissions"

      port = Port.open({:spawn, cmd}, [:binary, :exit_status, :stderr_to_stdout])
      status = stream_output(port)

      if status == 124 do
        IO.puts("\n---")
        IO.puts("ERROR: Claude timed out after #{@timeout_seconds} seconds")
      end

      System.halt(status)
    else
      IO.puts("No message provided, skipping Claude")
    end
  end

  defp stream_output(port) do
    receive do
      {^port, {:data, data}} ->
        data
        |> String.split("\n", trim: true)
        |> Enum.each(&process_line/1)
        stream_output(port)

      {^port, {:exit_status, status}} ->
        status
    end
  end

  defp process_line(line) do
    case Jason.decode(line) do
      # Handle streaming text deltas
      {:ok, %{"type" => "stream_event", "event" => %{"delta" => %{"text" => text}}}} ->
        IO.write(text)

      _ ->
        :ok  # Ignore other message types (result already streamed)
    end
  end
end
