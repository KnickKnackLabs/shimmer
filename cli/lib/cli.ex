defmodule Cli do
  @moduledoc """
  CLI interface for running Claude Code agents with streaming response handling.

  This module serves as the main escript entry point for orchestrating Claude AI
  interactions, managing system prompts, and streaming responses with tool tracking.
  """

  @logger_port 8000

  defp prompts_dir do
    # Try multiple paths - cwd might be repo root or cli directory
    cwd = File.cwd!()

    candidates = [
      # from repo root: ./cli/cli
      Path.join([cwd, "cli", "priv", "prompts"]),
      # from cli dir: mix test
      Path.join([cwd, "priv", "prompts"])
    ]

    Enum.find(candidates, List.first(candidates), &File.dir?/1)
  end

  def main(args) do
    {opts, rest} = parse_args(args)
    message = Enum.join(rest, " ")
    timeout = opts[:timeout]

    IO.puts("Running at: #{DateTime.utc_now()}")
    IO.puts("Message: #{message}")
    if timeout, do: IO.puts("Timeout: #{timeout}s")
    if opts[:agent], do: IO.puts("Agent: #{opts[:agent]}")
    if opts[:job], do: IO.puts("Job: #{opts[:job]}")
    if opts[:log_context], do: IO.puts("Context logging: enabled")
    IO.puts("---")

    cond do
      message == "" ->
        IO.puts("No message provided, skipping Claude")

      opts[:agent] == nil ->
        IO.puts("ERROR: --agent is required")
        System.halt(1)

      timeout == nil ->
        IO.puts("ERROR: --timeout is required")
        System.halt(1)

      true ->
        system_prompt = load_system_prompt(opts[:agent], opts[:job])

        if opts[:log_context] do
          run_with_logger(message, system_prompt, timeout)
        else
          run_claude(message, [], system_prompt, timeout)
        end
    end
  end

  defp parse_args(args) do
    {opts, rest, _} =
      OptionParser.parse(args,
        switches: [log_context: :boolean, agent: :string, job: :string, timeout: :integer]
      )

    {opts, rest}
  end

  @doc """
  Loads the system prompt for a given agent and optional job.

  Combines prompts in this order:
  1. Common prompt from `priv/prompts/common.txt`
  2. Agent identity from `priv/prompts/agents/{agent_name}.txt`
  3. Job description from `priv/prompts/jobs/{job_name}.txt` (if provided)

  Returns `nil` if `agent_name` is `nil`. Returns available prompts
  if some files are missing, or `nil` if all are missing.

  ## Examples

      iex> Cli.load_system_prompt(nil, nil)
      nil

  """
  def load_system_prompt(nil, _job), do: nil

  def load_system_prompt(agent_name, job_name) do
    dir = prompts_dir()

    parts =
      [
        read_prompt_file(Path.join([dir, "common.txt"])),
        read_prompt_file(Path.join([dir, "agents", "#{agent_name}.txt"])),
        if(job_name, do: read_prompt_file(Path.join([dir, "jobs", "#{job_name}.txt"])), else: "")
      ]
      |> Enum.reject(&(&1 == ""))

    case parts do
      [] -> nil
      parts -> Enum.join(parts, "\n\n")
    end
  end

  # Keep backward-compatible 1-arity version for tests
  def load_system_prompt(agent_name), do: load_system_prompt(agent_name, nil)

  defp read_prompt_file(path) do
    case File.read(path) do
      {:ok, content} ->
        content

      {:error, :enoent} ->
        ""

      {:error, reason} ->
        IO.puts("WARNING: Failed to read #{path}: #{reason}")
        ""
    end
  end

  defp run_claude(message, env_extras, system_prompt, timeout) do
    # Build claude arguments - message and system prompt passed as positional params to avoid escaping
    system_prompt_args =
      case system_prompt do
        nil -> ""
        _prompt -> " --append-system-prompt \"$2\""
      end

    # Shell script that pipes empty stdin and runs claude with timeout
    shell_script =
      "echo | timeout #{timeout} claude -p \"$1\"#{system_prompt_args} " <>
        "--model claude-opus-4-5-20251101 --output-format stream-json " <>
        "--verbose --include-partial-messages --dangerously-skip-permissions"

    # Build args list: -c script, --, message, [system_prompt]
    args =
      case system_prompt do
        nil -> ["-c", shell_script, "--", message]
        prompt -> ["-c", shell_script, "--", message, prompt]
      end

    # Convert env extras like "KEY=value" to {~c"KEY", ~c"value"} tuples
    env =
      Enum.map(env_extras, fn extra ->
        [key, value] = String.split(extra, "=", parts: 2)
        {String.to_charlist(key), String.to_charlist(value)}
      end)

    port =
      Port.open(
        {:spawn_executable, "/bin/sh"},
        [:binary, :exit_status, :stderr_to_stdout, {:args, args}, {:env, env}]
      )

    status = stream_output(port, %{tool_input: "", buffer: "", usage: nil})

    if status == 124 do
      IO.puts("\n---")
      IO.puts("ERROR: Claude timed out after #{timeout} seconds")
    end

    System.halt(status)
  end

  defp run_with_logger(message, system_prompt, timeout) do
    log_file = "/tmp/claude-context-#{:os.system_time(:second)}.log"

    # Start the logger in the background, using mise exec to ensure correct PATH
    logger_script =
      "mise exec -- claude-code-logger start --verbose --log-body > #{log_file} 2>&1"

    logger_port =
      Port.open(
        {:spawn_executable, "/bin/sh"},
        [:binary, {:args, ["-c", logger_script]}]
      )

    # Give the logger time to start
    Process.sleep(1500)

    # Verify the logger started by checking if the port is listening
    case System.cmd("nc", ["-z", "localhost", "#{@logger_port}"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("Logger started, output will be saved to: #{log_file}")
        IO.puts("---")

        # Run Claude through the proxy
        run_claude(
          message,
          ["ANTHROPIC_BASE_URL=http://localhost:#{@logger_port}"],
          system_prompt,
          timeout
        )

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

  defp stream_output(port, %{buffer: buffer} = state) do
    receive do
      {^port, {:data, data}} ->
        combined = buffer <> data
        lines = String.split(combined, "\n")

        # Last element may be incomplete - keep it as new buffer
        {complete_lines, [new_buffer]} = Enum.split(lines, -1)

        new_state =
          complete_lines
          |> Enum.reject(&(&1 == ""))
          |> Enum.reduce(%{state | buffer: new_buffer}, &process_line/2)

        stream_output(port, new_state)

      {^port, {:exit_status, status}} ->
        print_usage_summary(state)
        status
    end
  end

  @doc false
  def process_line(line, state) do
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

      # Capture final result with usage data
      {:ok, %{"type" => "result"} = result} ->
        %{state | usage: extract_usage(result)}

      _ ->
        state
    end
  end

  defp extract_usage(result) do
    %{
      cost_usd: Map.get(result, "total_cost_usd"),
      duration_ms: Map.get(result, "duration_ms"),
      num_turns: Map.get(result, "num_turns"),
      usage: Map.get(result, "usage"),
      model_usage: Map.get(result, "modelUsage")
    }
  end

  defp print_usage_summary(%{usage: nil}), do: :ok

  defp print_usage_summary(%{usage: usage}) do
    IO.puts("\n---")
    IO.puts("Run Metrics:")

    if usage.duration_ms do
      duration_s = Float.round(usage.duration_ms / 1000, 1)
      IO.puts("  Duration: #{duration_s}s")
    end

    if usage.num_turns, do: IO.puts("  Turns: #{usage.num_turns}")

    if usage.cost_usd do
      cost = Float.round(usage.cost_usd / 1, 4)
      IO.puts("  Cost: $#{cost}")
    end

    if usage.usage do
      input = Map.get(usage.usage, "input_tokens", 0)
      output = Map.get(usage.usage, "output_tokens", 0)
      cache_read = Map.get(usage.usage, "cache_read_input_tokens", 0)
      cache_create = Map.get(usage.usage, "cache_creation_input_tokens", 0)

      IO.puts("  Tokens: #{input} in, #{output} out")

      if cache_read > 0 or cache_create > 0 do
        IO.puts("  Cache: #{cache_read} read, #{cache_create} created")
      end
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
    old_preview = old |> truncate(60) |> String.replace("\n", "\\n")
    new_preview = new |> truncate(60) |> String.replace("\n", "\\n")
    "  #{path}\n  - #{old_preview}\n  + #{new_preview}"
  end

  def format_tool_input(%{"file_path" => path}) do
    "  -> #{path}"
  end

  def format_tool_input(%{"pattern" => pattern} = input) do
    case Map.get(input, "path") do
      nil -> "  pattern: #{pattern}"
      path -> "  #{path}\n  pattern: #{pattern}"
    end
  end

  def format_tool_input(%{"url" => url, "prompt" => prompt} = input) do
    desc = Map.get(input, "description", "")
    prompt_preview = truncate(prompt, 100)
    "  #{desc}\n  url: #{url}\n  prompt: #{prompt_preview}"
  end

  def format_tool_input(%{"prompt" => prompt} = input) do
    prompt_preview = truncate(prompt, 100)

    case Map.get(input, "description") do
      nil -> "  prompt: #{prompt_preview}"
      "" -> "  prompt: #{prompt_preview}"
      desc -> "  #{desc}\n  prompt: #{prompt_preview}"
    end
  end

  def format_tool_input(_), do: nil

  defp truncate(string, limit) do
    if String.length(string) > limit do
      String.slice(string, 0, limit) <> "..."
    else
      string
    end
  end
end
