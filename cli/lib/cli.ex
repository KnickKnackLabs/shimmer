defmodule Cli do
  @moduledoc """
  CLI interface for running Claude Code agents with streaming response handling.

  This module provides the main entry point for orchestrating Claude AI
  interactions, managing system prompts, and streaming responses with tool tracking.
  """

  use Application

  @impl Application
  def start(_type, _args) do
    # Spawn CLI execution in a separate process to allow proper VM initialization
    Task.start(fn ->
      args = get_argv()
      exit_code = run(args)
      System.halt(exit_code)
    end)
  end

  # Get command line arguments, preferring Burrito's argv when available
  # Uses apply/3 to avoid compile-time warning since Burrito is prod-only
  defp get_argv do
    if Code.ensure_loaded?(Burrito.Util.Args) do
      apply(Burrito.Util.Args, :argv, [])
    else
      System.argv()
    end
  end

  @logger_port 8000
  @logger_connect_retries 10
  @logger_connect_interval_ms 200
  @logger_connect_timeout_ms 100
  @default_model "claude-opus-4-5-20251101"
  @truncate_edit_limit 60
  @truncate_prompt_limit 100
  @buffer_flush_timeout_ms 100
  # Exit code returned by the `timeout` command when the process exceeds the time limit
  @timeout_exit_code 124

  defp prompts_dir do
    :code.priv_dir(:cli) |> List.to_string() |> Path.join("prompts")
  end

  @doc """
  CLI entry point. Parses args, runs the CLI, and exits with the returned status.
  """
  @spec main([String.t()]) :: no_return()
  def main(args) do
    args |> run() |> System.halt()
  end

  @doc """
  Runs the CLI with the given arguments and returns an exit code.
  Does not call System.halt - suitable for testing.
  """
  @spec run([String.t()]) :: non_neg_integer()
  def run(args) do
    {opts, rest} = parse_args(args)

    if opts[:help] do
      print_help()
      0
    else
      run_with_opts(opts, rest)
    end
  end

  defp run_with_opts(opts, rest) do
    message = Enum.join(rest, " ")
    timeout = opts[:timeout]
    agent = opts[:agent]
    model = opts[:model] || @default_model

    print_header(opts, message, timeout, agent, model)

    case validate_args(message, agent, opts[:job], timeout) do
      {:error, msg} ->
        IO.puts("ERROR: #{msg}")
        1

      :ok ->
        system_prompt = load_system_prompt(agent, opts[:job])

        if opts[:log_context] do
          run_with_logger(message, system_prompt, timeout, model)
        else
          run_claude(message, [], system_prompt, timeout, model)
        end
    end
  end

  defp print_header(opts, message, timeout, agent, model) do
    IO.puts("Running at: #{DateTime.utc_now()}")
    IO.puts("Message: #{message}")
    if timeout, do: IO.puts("Timeout: #{timeout}s")
    if agent, do: IO.puts("Agent: #{agent}")
    if opts[:job], do: IO.puts("Job: #{opts[:job]}")
    IO.puts("Model: #{model}")
    if opts[:log_context], do: IO.puts("Context logging: enabled")
    IO.puts("---")
  end

  defp validate_args(message, agent, job, timeout) do
    cond do
      String.trim(message) == "" ->
        {:error, "No message provided"}

      agent == nil or agent == "" ->
        {:error, "--agent is required and cannot be empty"}

      not safe_name?(agent) ->
        {:error, "--agent must contain only alphanumeric characters, hyphens, and underscores"}

      job != nil and not safe_name?(job) ->
        {:error, "--job must contain only alphanumeric characters, hyphens, and underscores"}

      timeout == nil ->
        {:error, "--timeout is required"}

      timeout <= 0 ->
        {:error, "--timeout must be greater than 0"}

      true ->
        :ok
    end
  end

  # Validates that a name is safe for use in file paths (prevents path traversal)
  defp safe_name?(name), do: Regex.match?(~r/^[a-zA-Z0-9_-]+$/, name)

  defp parse_args(args) do
    {opts, rest, invalid} =
      OptionParser.parse(args,
        strict: [
          log_context: :boolean,
          agent: :string,
          job: :string,
          timeout: :integer,
          model: :string,
          help: :boolean
        ],
        aliases: [h: :help]
      )

    if invalid != [] do
      invalid_names = Enum.map(invalid, fn {name, _} -> name end) |> Enum.join(", ")
      IO.puts("WARNING: Unknown arguments ignored: #{invalid_names}")
    end

    {opts, rest}
  end

  defp print_help do
    IO.puts("""
    Usage: shimmer --agent <name> --timeout <seconds> [options] <message>

    Run Claude Code with a specific agent persona and streaming output.

    Required:
      --agent <name>       Agent persona (e.g., quick, junior, brownie)
      --timeout <seconds>  Maximum runtime in seconds

    Options:
      --job <name>         Job-specific prompt (e.g., probe, critic)
      --model <model>      Claude model to use (default: claude-opus-4-5-20251101)
      --log-context        Enable context logging via proxy
      -h, --help           Show this help message

    Examples:
      shimmer --agent quick --timeout 300 "Fix the bug in cli.ex"
      shimmer --agent brownie --timeout 600 --job probe "Explore the codebase"
    """)
  end

  @doc """
  Loads the system prompt for a given agent and optional job.

  Combines prompts in this order:
  1. Common prompt from `priv/prompts/common.txt`
  2. Agent identity from `priv/prompts/agents/{agent_name}.txt`
  3. Job description from `priv/prompts/jobs/{job_name}.txt` (if provided)

  Returns `nil` if `agent_name` is `nil` or empty. Returns the combined
  prompt content if at least one file exists, or `nil` if all are missing.

  ## Examples

      iex> Cli.load_system_prompt(nil, nil)
      nil

  """
  @spec load_system_prompt(String.t() | nil, String.t() | nil) :: String.t() | nil
  def load_system_prompt(nil, _job), do: nil
  def load_system_prompt("", _job), do: nil

  def load_system_prompt(agent_name, job_name) do
    dir = prompts_dir()

    agent_path = Path.join([dir, "agents", "#{agent_name}.txt"])
    warn_if_missing(agent_path, :agent, agent_name, dir)

    job_path = if job_name, do: Path.join([dir, "jobs", "#{job_name}.txt"]), else: nil
    if job_path, do: warn_if_missing(job_path, :job, job_name, dir)

    parts =
      [
        read_prompt_file(Path.join([dir, "common.txt"])),
        read_prompt_file(agent_path),
        if(job_path, do: read_prompt_file(job_path), else: "")
      ]
      |> Enum.reject(&(&1 == ""))

    case parts do
      [] -> nil
      parts -> Enum.join(parts, "\n\n")
    end
  end

  # Keep backward-compatible 1-arity version for tests
  @spec load_system_prompt(String.t() | nil) :: String.t() | nil
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

  defp warn_if_missing(path, type, name, prompts_dir) do
    unless File.exists?(path) do
      type_name = if type == :agent, do: "Agent", else: "Job"
      subdir = if type == :agent, do: "agents", else: "jobs"
      available = list_available(prompts_dir, subdir)

      available_hint =
        if available != [], do: " Available: #{Enum.join(available, ", ")}", else: ""

      IO.puts("WARNING: #{type_name} prompt not found: #{name}.txt#{available_hint}")
    end
  end

  defp list_available(prompts_dir, subdir) do
    dir = Path.join(prompts_dir, subdir)

    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".txt"))
        |> Enum.map(&String.replace_suffix(&1, ".txt", ""))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  defp run_claude(message, env_extras, system_prompt, timeout, model) do
    # Build claude arguments - message and system prompt passed as positional params to avoid escaping
    system_prompt_args =
      case system_prompt do
        nil -> ""
        _prompt -> " --append-system-prompt \"$2\""
      end

    # Shell script that pipes empty stdin and runs claude with timeout
    # All user-controlled values ($1=message, $2=system_prompt, $3=model) are passed as
    # positional parameters to avoid shell injection vulnerabilities
    shell_script =
      "echo | timeout #{timeout} claude -p \"$1\"#{system_prompt_args} " <>
        "--model \"$3\" --output-format stream-json " <>
        "--verbose --include-partial-messages --dangerously-skip-permissions"

    # Build args list: -c script, --, message, system_prompt (or empty), model
    args =
      case system_prompt do
        nil -> ["-c", shell_script, "--", message, "", model]
        prompt -> ["-c", shell_script, "--", message, prompt, model]
      end

    # Convert env extras like "KEY=value" to {~c"KEY", ~c"value"} tuples
    env =
      env_extras
      |> Enum.map(&parse_env_extra/1)
      |> Enum.reject(&is_nil/1)

    port =
      Port.open(
        {:spawn_executable, "/bin/sh"},
        [:binary, :exit_status, :stderr_to_stdout, {:args, args}, {:env, env}]
      )

    status =
      stream_output(port, %{
        tool_input: "",
        buffer: "",
        usage: nil,
        abort_seen: false,
        recent_text: "",
        flushed_text: ""
      })

    if status == @timeout_exit_code do
      IO.puts("\n---")
      IO.puts("ERROR: Claude timed out after #{timeout} seconds")
    end

    status
  end

  defp run_with_logger(message, system_prompt, timeout, model) do
    # Use microseconds + random suffix to avoid collision when multiple CLI processes start close together
    random_suffix = :rand.uniform(0xFFFF) |> Integer.to_string(16) |> String.pad_leading(4, "0")
    log_file = "/tmp/claude-context-#{:os.system_time(:microsecond)}-#{random_suffix}.log"

    # Start the logger in the background, using mise exec to ensure correct PATH
    logger_script =
      "mise exec -- claude-code-logger start --verbose --log-body > #{log_file} 2>&1"

    logger_port =
      Port.open(
        {:spawn_executable, "/bin/sh"},
        [:binary, {:args, ["-c", logger_script]}]
      )

    # Wait for logger to start with retry loop
    case wait_for_port(@logger_port, @logger_connect_retries, @logger_connect_interval_ms) do
      :ok ->
        IO.puts("Logger started, output will be saved to: #{log_file}")
        IO.puts("---")

        # Run Claude through the proxy
        status =
          run_claude(
            message,
            ["ANTHROPIC_BASE_URL=http://localhost:#{@logger_port}"],
            system_prompt,
            timeout,
            model
          )

        stop_logger(logger_port)
        status

      :error ->
        stop_logger(logger_port)
        IO.puts("ERROR: Failed to start claude-code-logger")
        IO.puts("Check if it's installed: mise exec -- claude-code-logger --version")

        # Show what's in the log file for debugging
        case File.read(log_file) do
          {:ok, content} when content != "" -> IO.puts("Logger output: #{content}")
          _ -> :ok
        end

        1
    end
  end

  # Parse a single env extra string like "KEY=value" into a charlist tuple
  # Returns nil and logs a warning for malformed entries
  defp parse_env_extra(extra) do
    case String.split(extra, "=", parts: 2) do
      [key, value] ->
        {String.to_charlist(key), String.to_charlist(value)}

      _ ->
        IO.puts("WARNING: Ignoring malformed env extra: #{extra}")
        nil
    end
  end

  # Stop the logger process by killing the OS process, then closing the port
  # Port.close alone doesn't terminate the child process
  defp stop_logger(logger_port) do
    case Port.info(logger_port, :os_pid) do
      {:os_pid, os_pid} ->
        case System.cmd("kill", ["#{os_pid}"], stderr_to_stdout: true) do
          {_, 0} ->
            :ok

          {output, status} ->
            IO.puts(
              "WARNING: Failed to kill logger (pid #{os_pid}): exit #{status} - #{String.trim(output)}"
            )
        end

        Port.close(logger_port)

      nil ->
        # Port already closed
        :ok
    end
  end

  # Wait for a port to become available using Elixir's built-in :gen_tcp
  # More reliable than external tools like netcat
  defp wait_for_port(_port, 0, _interval), do: :error

  defp wait_for_port(port, retries, interval) do
    case :gen_tcp.connect(~c"localhost", port, [], @logger_connect_timeout_ms) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :ok

      {:error, _} ->
        Process.sleep(interval)
        wait_for_port(port, retries - 1, interval)
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
        # Flush any remaining buffer content before exit (issue #367)
        if buffer != "" do
          flush_partial_buffer(buffer)
        end

        print_usage_summary(state)

        # If agent signaled abort, override exit status
        if state.abort_seen do
          IO.puts("\n---")
          IO.puts("Agent requested session abort via [[ABORT]]")
          1
        else
          status
        end
    after
      @buffer_flush_timeout_ms ->
        # Flush partial buffer on timeout to show long lines in progress
        # Keep buffer intact so continuation data isn't lost (issue #338)
        case buffer do
          "" ->
            stream_output(port, state)

          partial ->
            # Extract text from current partial buffer
            extracted = extract_partial_text(partial)

            # Only output the new text beyond what was already flushed
            new_text =
              if String.starts_with?(extracted, state.flushed_text) do
                String.slice(
                  extracted,
                  String.length(state.flushed_text),
                  String.length(extracted)
                )
              else
                # Flushed text doesn't match - shouldn't happen, but output everything
                extracted
              end

            if new_text != "" do
              IO.write(new_text)
            end

            # Track all text we've shown from this buffer
            stream_output(port, %{state | flushed_text: extracted})
        end
    end
  end

  @doc """
  Extract text from incomplete JSON lines in the buffer without processing as JSON.
  These are partial lines that haven't completed yet, so we try to extract
  any text content for display.

  Returns the unescaped text that was extracted, or empty string if none found.
  """
  @spec extract_partial_text(String.t()) :: String.t()
  def extract_partial_text(partial) do
    # Try to extract text from partial JSON if it looks like a streaming event
    # Pattern: look for "text":" followed by content
    case Regex.run(~r/"text"\s*:\s*"((?:[^"\\]|\\.)*)$/, partial) do
      [_, text] ->
        # Complete the JSON string and use Jason to handle all escape sequences
        # This properly handles \r, \b, \f, \/, \uXXXX in addition to \n, \t, \\, \"
        case Jason.decode("\"#{text}\"") do
          {:ok, unescaped} -> unescaped
          {:error, _} -> ""
        end

      nil ->
        ""
    end
  end

  @doc """
  Flush incomplete JSON lines from the buffer without processing them as JSON.
  Writes extracted text to stdout. This is a convenience wrapper around
  `extract_partial_text/1`.

  Returns `:ok` after writing any extracted text to stdout.
  """
  @spec flush_partial_buffer(String.t()) :: :ok
  def flush_partial_buffer(partial) do
    case extract_partial_text(partial) do
      "" -> :ok
      text -> IO.write(text)
    end
  end

  @typep stream_state :: %{
           tool_input: String.t(),
           buffer: String.t(),
           usage: map() | nil,
           abort_seen: boolean(),
           recent_text: String.t(),
           flushed_text: String.t()
         }

  @doc false
  @spec process_line(String.t(), stream_state()) :: stream_state()
  def process_line(line, state) do
    case Jason.decode(line) do
      # Handle streaming text deltas
      {:ok, %{"type" => "stream_event", "event" => %{"delta" => %{"text" => text}}}} ->
        # Write text, skipping any prefix already shown via partial flush (issue #338)
        write_text_delta(text, state.flushed_text)
        # Keep a sliding window of recent text to detect [[ABORT]] across chunk boundaries
        # The signal is 11 chars, so we keep 20 to ensure we can always match it
        recent_text = String.slice(state.recent_text <> text, -20, 20)
        abort_seen = state.abort_seen || Regex.match?(~r/^\[\[ABORT\]\]$/m, recent_text)
        # Reset flushed_text since this line is now complete
        %{state | abort_seen: abort_seen, recent_text: recent_text, flushed_text: ""}

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

  # Write text delta, skipping any prefix that was already flushed (issue #338)
  defp write_text_delta(text, flushed_text) do
    text_to_write =
      if flushed_text != "" && String.starts_with?(text, flushed_text) do
        String.slice(text, String.length(flushed_text), String.length(text))
      else
        text
      end

    if text_to_write != "" do
      IO.write(text_to_write)
    end

    :ok
  end

  defp print_usage_summary(%{usage: nil}), do: :ok

  defp print_usage_summary(%{usage: usage}) do
    IO.puts("\n---")
    IO.puts("Run Metrics:")

    if usage.duration_ms do
      duration_s = :erlang.float_to_binary(usage.duration_ms / 1000, decimals: 1)
      IO.puts("  Duration: #{duration_s}s")
    end

    if usage.num_turns, do: IO.puts("  Turns: #{usage.num_turns}")

    if usage.cost_usd do
      cost = :erlang.float_to_binary(usage.cost_usd, decimals: 4)
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
  @spec format_tool_input(map()) :: String.t() | nil
  def format_tool_input(%{"command" => cmd}) do
    "  $ #{cmd}"
  end

  def format_tool_input(%{"file_path" => path, "old_string" => old, "new_string" => new}) do
    old_preview = old |> truncate(@truncate_edit_limit) |> String.replace("\n", "\\n")
    new_preview = new |> truncate(@truncate_edit_limit) |> String.replace("\n", "\\n")
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
    prompt_preview = truncate(prompt, @truncate_prompt_limit)

    case Map.get(input, "description") do
      desc when desc in [nil, ""] -> "  url: #{url}\n  prompt: #{prompt_preview}"
      desc -> "  #{desc}\n  url: #{url}\n  prompt: #{prompt_preview}"
    end
  end

  def format_tool_input(%{"prompt" => prompt} = input) do
    prompt_preview = truncate(prompt, @truncate_prompt_limit)

    case Map.get(input, "description") do
      desc when desc in [nil, ""] -> "  prompt: #{prompt_preview}"
      desc -> "  #{desc}\n  prompt: #{prompt_preview}"
    end
  end

  def format_tool_input(%{"todos" => todos}) when is_list(todos) do
    count = length(todos)
    first = List.first(todos)

    preview =
      case first do
        %{"content" => content} when is_binary(content) -> ": #{truncate(content, 50)}"
        _ -> ""
      end

    "  #{count} todo(s)#{preview}"
  end

  def format_tool_input(%{"query" => query}) do
    "  search: #{truncate(query, 80)}"
  end

  def format_tool_input(%{"operation" => op, "filePath" => path, "line" => line}) do
    "  #{op} at #{path}:#{line}"
  end

  def format_tool_input(%{"skill" => skill} = input) do
    case Map.get(input, "args") do
      nil -> "  skill: #{skill}"
      args -> "  skill: #{skill} #{truncate(args, 50)}"
    end
  end

  def format_tool_input(%{"shell_id" => id}) do
    "  shell: #{id}"
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
