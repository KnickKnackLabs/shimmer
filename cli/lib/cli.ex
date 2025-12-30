defmodule Cli do
  @timeout_seconds 540  # 9 minutes, leaves 1 minute buffer before GitHub's 10-minute timeout

  def main(args) do
    message = Enum.join(args, " ")
    IO.puts("Running at: #{DateTime.utc_now()}")
    IO.puts("Message: #{message}")
    IO.puts("Timeout: #{@timeout_seconds}s")
    IO.puts("---")

    if message != "" do
      escaped_message = String.replace(message, "'", "'\\''")
      # Pipe empty stdin to close it, use stream-json with --verbose and --include-partial-messages for real streaming
      cmd = "echo | timeout #{@timeout_seconds} claude -p '#{escaped_message}' --model claude-opus-4-5-20251101 --output-format stream-json --verbose --include-partial-messages --dangerously-skip-permissions"

      port = Port.open({:spawn, cmd}, [:binary, :exit_status, :stderr_to_stdout])
      status = stream_output(port, %{tool_input: ""})

      if status == 124 do
        IO.puts("\n---")
        IO.puts("ERROR: Claude timed out after #{@timeout_seconds} seconds")
      end

      System.halt(status)
    else
      IO.puts("No message provided, skipping Claude")
    end
  end

  defp stream_output(port, state) do
    receive do
      {^port, {:data, data}} ->
        new_state =
          data
          |> String.split("\n", trim: true)
          |> Enum.reduce(state, &process_line/2)
        stream_output(port, new_state)

      {^port, {:exit_status, status}} ->
        status
    end
  end

  defp process_line(line, state) do
    case Jason.decode(line) do
      # Handle streaming text deltas
      {:ok, %{"type" => "stream_event", "event" => %{"delta" => %{"text" => text}}}} ->
        IO.write(text)
        state

      # Handle tool use start - show which tool is being called
      {:ok, %{"type" => "stream_event", "event" => %{"content_block" => %{"type" => "tool_use", "name" => name}}}} ->
        IO.puts("\n[TOOL] #{name}")
        %{state | tool_input: ""}

      # Handle tool input streaming - accumulate the JSON
      {:ok, %{"type" => "stream_event", "event" => %{"delta" => %{"partial_json" => json}}}} ->
        %{state | tool_input: state.tool_input <> json}

      # Handle tool completion - show the accumulated input
      {:ok, %{"type" => "stream_event", "event" => %{"type" => "content_block_stop"}}} ->
        if state.tool_input != "" do
          case Jason.decode(state.tool_input) do
            {:ok, input} -> print_tool_input(input)
            _ -> :ok
          end
        end
        %{state | tool_input: ""}

      _ ->
        state
    end
  end

  defp print_tool_input(%{"command" => cmd}) do
    IO.puts("  $ #{cmd}")
  end

  defp print_tool_input(%{"file_path" => path}) do
    IO.puts("  -> #{path}")
  end

  defp print_tool_input(%{"pattern" => pattern}) do
    IO.puts("  pattern: #{pattern}")
  end

  defp print_tool_input(%{"prompt" => prompt} = input) do
    desc = Map.get(input, "description", "")
    IO.puts("  #{desc}")
    IO.puts("  prompt: #{String.slice(prompt, 0, 100)}...")
  end

  defp print_tool_input(%{"old_string" => old, "new_string" => new, "file_path" => path}) do
    IO.puts("  #{path}")
    IO.puts("  - #{String.slice(old, 0, 60) |> String.replace("\n", "\\n")}...")
    IO.puts("  + #{String.slice(new, 0, 60) |> String.replace("\n", "\\n")}...")
  end

  defp print_tool_input(_), do: :ok
end
