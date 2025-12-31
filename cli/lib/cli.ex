defmodule Cli do
  # 9 minutes, leaves 1 minute buffer before GitHub's 10-minute timeout
  @timeout_seconds 540
  @model "claude-opus-4-5-20251101"

  def main(args) do
    message = Enum.join(args, " ")
    start_time = System.monotonic_time(:millisecond)

    IO.puts("Running at: #{DateTime.utc_now()}")
    IO.puts("Message: #{message}")
    IO.puts("Timeout: #{@timeout_seconds}s")
    IO.puts("---")

    if message != "" do
      escaped_message = String.replace(message, "'", "'\\''")

      # Pipe empty stdin to close it, use stream-json with --verbose and --include-partial-messages for real streaming
      cmd =
        "echo | timeout #{@timeout_seconds} claude -p '#{escaped_message}' --model #{@model} --output-format stream-json --verbose --include-partial-messages --dangerously-skip-permissions"

      initial_state = %{tool_input: "", tool_calls: %{}}
      port = Port.open({:spawn, cmd}, [:binary, :exit_status, :stderr_to_stdout])
      {status, final_state} = stream_output(port, initial_state)

      if status == 124 do
        IO.puts("\n---")
        IO.puts("ERROR: Claude timed out after #{@timeout_seconds} seconds")
      end

      duration_ms = System.monotonic_time(:millisecond) - start_time
      print_metrics(duration_ms, final_state.tool_calls, @model, status)

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
        {status, state}
    end
  end

  defp process_line(line, state) do
    case Jason.decode(line) do
      # Handle streaming text deltas
      {:ok, %{"type" => "stream_event", "event" => %{"delta" => %{"text" => text}}}} ->
        IO.write(text)
        state

      # Handle tool use start - show which tool is being called
      {:ok,
       %{
         "type" => "stream_event",
         "event" => %{"content_block" => %{"type" => "tool_use", "name" => name}}
       }} ->
        IO.puts("\n[TOOL] #{name}")
        tool_calls = Map.update(state.tool_calls, name, 1, &(&1 + 1))
        %{state | tool_input: "", tool_calls: tool_calls}

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

  defp print_tool_input(input) do
    case format_tool_input(input) do
      nil -> :ok
      output -> IO.puts(output)
    end
  end

  @doc """
  Formats tool input map into a human-readable string for display.
  Returns nil for unrecognized input formats.
  """
  def format_tool_input(%{"command" => cmd}) do
    "  $ #{cmd}"
  end

  def format_tool_input(%{"file_path" => path, "old_string" => old, "new_string" => new}) do
    old_preview = old |> String.slice(0, 60) |> String.replace("\n", "\\n")
    new_preview = new |> String.slice(0, 60) |> String.replace("\n", "\\n")
    "  #{path}\n  - #{old_preview}...\n  + #{new_preview}..."
  end

  def format_tool_input(%{"file_path" => path}) do
    "  -> #{path}"
  end

  def format_tool_input(%{"pattern" => pattern}) do
    "  pattern: #{pattern}"
  end

  def format_tool_input(%{"prompt" => prompt} = input) do
    desc = Map.get(input, "description", "")
    prompt_preview = String.slice(prompt, 0, 100)
    "  #{desc}\n  prompt: #{prompt_preview}..."
  end

  def format_tool_input(_), do: nil

  defp print_metrics(duration_ms, tool_calls, model, status) do
    IO.puts("\n---")
    IO.puts("Run Metrics:")

    # Duration
    duration_s = duration_ms / 1000
    minutes = trunc(duration_s / 60)
    seconds = Float.round(duration_s - minutes * 60, 1)
    IO.puts("  Duration: #{minutes}m #{seconds}s")

    # Model
    IO.puts("  Model: #{model}")

    # Exit status
    status_desc =
      case status do
        0 -> "success"
        124 -> "timeout"
        _ -> "error (#{status})"
      end

    IO.puts("  Exit: #{status_desc}")

    # Tool calls
    total_calls = tool_calls |> Map.values() |> Enum.sum()
    IO.puts("  Tool calls: #{total_calls}")

    if total_calls > 0 do
      tool_calls
      |> Enum.sort_by(fn {_name, count} -> -count end)
      |> Enum.each(fn {name, count} ->
        IO.puts("    #{name}: #{count}")
      end)
    end
  end
end
