defmodule Cli do
  # 9 minutes, leaves 1 minute buffer before GitHub's 10-minute timeout
  @timeout_seconds 540
  @logger_port 8000

  def main(args) do
    {opts, rest} = parse_args(args)
    message = Enum.join(rest, " ")

    IO.puts("Running at: #{DateTime.utc_now()}")
    IO.puts("Message: #{message}")
    IO.puts("Timeout: #{@timeout_seconds}s")
    if opts[:log_context], do: IO.puts("Context logging: enabled")
    IO.puts("---")

    if message != "" do
      if opts[:log_context] do
        run_with_logger(message)
      else
        run_claude(message)
      end
    else
      IO.puts("No message provided, skipping Claude")
    end
  end

  defp parse_args(args) do
    {opts, rest, _} = OptionParser.parse(args, switches: [log_context: :boolean])
    {opts, rest}
  end

  defp run_claude(message, env_extras \\ []) do
    escaped_message = String.replace(message, "'", "'\\''")

    env_prefix =
      case env_extras do
        [] -> ""
        extras -> Enum.join(extras, " ") <> " "
      end

    # Pipe empty stdin to close it, use stream-json with --verbose and --include-partial-messages for real streaming
    cmd =
      "echo | #{env_prefix}timeout #{@timeout_seconds} claude -p '#{escaped_message}' --model claude-opus-4-5-20251101 --output-format stream-json --verbose --include-partial-messages --dangerously-skip-permissions"

    port = Port.open({:spawn, cmd}, [:binary, :exit_status, :stderr_to_stdout])
    status = stream_output(port, %{tool_input: ""})

    if status == 124 do
      IO.puts("\n---")
      IO.puts("ERROR: Claude timed out after #{@timeout_seconds} seconds")
    end

    System.halt(status)
  end

  defp run_with_logger(message) do
    log_file = "/tmp/claude-context-#{:os.system_time(:second)}.log"

    # Start the logger in the background, using mise exec to ensure correct PATH
    logger_cmd = "mise exec -- claude-code-logger start --verbose --log-body > #{log_file} 2>&1"
    logger_port = Port.open({:spawn, logger_cmd}, [:binary])

    # Give the logger time to start
    Process.sleep(1500)

    # Verify the logger started by checking if the port is listening
    case System.cmd("nc", ["-z", "localhost", "#{@logger_port}"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("Logger started, output will be saved to: #{log_file}")
        IO.puts("---")

        # Run Claude through the proxy
        run_claude(message, ["ANTHROPIC_BASE_URL=http://localhost:#{@logger_port}"])

        # Note: System.halt in run_claude will terminate before we get here
        Port.close(logger_port)

      {_, _} ->
        Port.close(logger_port)
        IO.puts("ERROR: Failed to start claude-code-logger")
        IO.puts("Check if it's installed: mise exec -- claude-code-logger --version")

        # Show what's in the log file for debugging
        case File.read(log_file) do
          {:ok, content} when content != "" -> IO.puts("Logger output: #{content}")
          _ -> :ok
        end

        System.halt(1)
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
      {:ok,
       %{
         "type" => "stream_event",
         "event" => %{"content_block" => %{"type" => "tool_use", "name" => name}}
       }} ->
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
end
