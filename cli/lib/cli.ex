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
      # Pipe empty stdin to close it, use stream-json with --verbose for streaming
      # Use stdbuf to disable output buffering
      cmd = "echo | stdbuf -oL timeout #{@timeout_seconds} claude -p '#{escaped_message}' --output-format stream-json --verbose --dangerously-skip-permissions"

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
      {:ok, %{"type" => "content_block_delta", "delta" => %{"text" => text}}} ->
        IO.write(text)
        :io.put_chars(:standard_io, [])  # flush

      {:ok, %{"type" => "result", "result" => result}} ->
        IO.write(result)

      _ ->
        :ok  # Ignore other message types
    end
  end
end
