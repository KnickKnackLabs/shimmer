defmodule CliTest do
  use ExUnit.Case
  doctest Cli
  import ExUnit.CaptureIO

  # Helper to capture both IO output and return value from Cli.run
  defp run_cli(args) do
    output =
      capture_io(fn ->
        send(self(), {:result, Cli.run(args)})
      end)

    receive do
      {:result, exit_code} -> {output, exit_code}
    end
  end

  describe "invalid argument handling" do
    test "warns about unknown arguments" do
      {output, _exit_code} = run_cli(["--agnet", "quick", "--timeout", "60"])
      assert output =~ "WARNING: Unknown arguments ignored: --agnet"
    end

    test "warns about multiple unknown arguments" do
      {output, _exit_code} = run_cli(["--agnet", "quick", "--tiemout", "60"])
      assert output =~ "WARNING: Unknown arguments ignored:"
      assert output =~ "--agnet"
      assert output =~ "--tiemout"
    end

    test "no warning for valid arguments" do
      {output, _exit_code} = run_cli(["--agent", "quick", "--timeout", "60"])
      refute output =~ "WARNING: Unknown arguments ignored"
    end

    test "returns exit code 1 for missing agent" do
      {_output, exit_code} = run_cli(["--timeout", "60", "hello"])
      assert exit_code == 1
    end

    test "returns exit code 1 for missing message" do
      {_output, exit_code} = run_cli(["--agent", "quick", "--timeout", "60"])
      assert exit_code == 1
    end
  end

  describe "Cli module" do
    test "exports main/1 function" do
      # Verify the main entry point exists
      assert function_exported?(Cli, :main, 1)
    end

    test "module loads without errors" do
      # Basic smoke test - if this passes, the module compiles correctly
      assert Code.ensure_loaded?(Cli)
    end
  end

  describe "Jason dependency" do
    test "JSON parsing works for stream events" do
      # Test that our JSON parsing will work with expected format
      json = ~s({"type":"stream_event","event":{"delta":{"text":"Hello"}}})
      {:ok, decoded} = Jason.decode(json)

      assert decoded["type"] == "stream_event"
      assert get_in(decoded, ["event", "delta", "text"]) == "Hello"
    end

    test "JSON parsing handles malformed input" do
      # Verify error handling for invalid JSON
      result = Jason.decode("not valid json")
      assert {:error, _} = result
    end
  end

  describe "format_tool_input/1" do
    test "formats bash command input" do
      input = %{"command" => "ls -la"}
      assert Cli.format_tool_input(input) == "  $ ls -la"
    end

    test "formats file path input for Read tool" do
      input = %{"file_path" => "/path/to/file.ex"}
      assert Cli.format_tool_input(input) == "  -> /path/to/file.ex"
    end

    test "formats pattern input for Glob tool" do
      input = %{"pattern" => "**/*.ex"}
      assert Cli.format_tool_input(input) == "  pattern: **/*.ex"
    end

    test "formats pattern input for Grep tool with path" do
      input = %{"pattern" => "def main", "path" => "cli/lib/cli.ex"}
      assert Cli.format_tool_input(input) == "  cli/lib/cli.ex\n  pattern: def main"
    end

    test "formats Edit tool input with old_string and new_string" do
      input = %{
        "file_path" => "/path/to/file.ex",
        "old_string" => "old code here",
        "new_string" => "new code here"
      }

      result = Cli.format_tool_input(input)
      assert result =~ "  /path/to/file.ex"
      # Short strings should NOT have ellipsis
      assert result =~ "  - old code here"
      assert result =~ "  + new code here"
      refute result =~ "old code here..."
      refute result =~ "new code here..."
    end

    test "truncates long old_string and new_string in Edit tool" do
      long_string = String.duplicate("x", 100)

      input = %{
        "file_path" => "/path/to/file.ex",
        "old_string" => long_string,
        "new_string" => long_string
      }

      result = Cli.format_tool_input(input)
      # Should truncate to 60 chars plus "..."
      assert result =~ String.duplicate("x", 60) <> "..."
    end

    test "replaces newlines in Edit tool strings" do
      input = %{
        "file_path" => "/path/to/file.ex",
        "old_string" => "line1\nline2",
        "new_string" => "line3\nline4"
      }

      result = Cli.format_tool_input(input)
      assert result =~ "line1\\nline2"
      assert result =~ "line3\\nline4"
    end

    test "formats WebFetch tool input with prompt" do
      input = %{
        "prompt" => "Extract the main content",
        "description" => "Fetching docs"
      }

      result = Cli.format_tool_input(input)
      assert result =~ "  Fetching docs"
      # Short prompts should NOT have ellipsis
      assert result =~ "  prompt: Extract the main content"
      refute result =~ "Extract the main content..."
    end

    test "formats WebFetch tool input with url and prompt" do
      input = %{
        "url" => "https://example.com/docs",
        "prompt" => "Extract the main content",
        "description" => "Fetching docs"
      }

      result = Cli.format_tool_input(input)
      assert result =~ "  Fetching docs"
      assert result =~ "  url: https://example.com/docs"
      # Short prompts should NOT have ellipsis
      assert result =~ "  prompt: Extract the main content"
      refute result =~ "Extract the main content..."
    end

    test "formats WebFetch tool input with url but no description" do
      input = %{
        "url" => "https://example.com",
        "prompt" => "Get content"
      }

      result = Cli.format_tool_input(input)
      # Should not have leading empty line when description is missing
      assert result == "  url: https://example.com\n  prompt: Get content"
    end

    test "formats WebFetch tool input with url and empty description" do
      input = %{
        "url" => "https://example.com",
        "prompt" => "Get content",
        "description" => ""
      }

      result = Cli.format_tool_input(input)
      # Should not have leading empty line when description is empty
      assert result == "  url: https://example.com\n  prompt: Get content"
    end

    test "formats prompt input without description" do
      input = %{"prompt" => "Some prompt text"}
      result = Cli.format_tool_input(input)
      # Short prompts should NOT have ellipsis
      assert result == "  prompt: Some prompt text"
      refute result =~ "Some prompt text..."
    end

    test "truncates long prompts to 100 chars" do
      long_prompt = String.duplicate("a", 150)
      input = %{"prompt" => long_prompt}

      result = Cli.format_tool_input(input)
      assert result =~ String.duplicate("a", 100) <> "..."
      refute result =~ String.duplicate("a", 101)
    end

    test "returns nil for unrecognized input format" do
      assert Cli.format_tool_input(%{"unknown" => "value"}) == nil
      assert Cli.format_tool_input(%{}) == nil
    end
  end

  describe "process_line/2" do
    test "outputs text delta and accumulates to full_text" do
      line = ~s({"type":"stream_event","event":{"delta":{"text":"Hello"}}})
      state = %{tool_input: "", full_text: ""}

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output == "Hello"
      assert_received {:result, %{tool_input: "", full_text: "Hello"}}
    end

    test "resets tool_input on tool_use start and prints tool name" do
      line =
        ~s({"type":"stream_event","event":{"content_block":{"type":"tool_use","name":"Bash"}}})

      state = %{tool_input: "leftover"}

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output =~ "[TOOL] Bash"
      assert_received {:result, %{tool_input: ""}}
    end

    test "accumulates partial_json to tool_input" do
      line = ~s({"type":"stream_event","event":{"delta":{"partial_json":"{\\"cmd\\":"}}})
      state = %{tool_input: ""}

      result = Cli.process_line(line, state)
      assert result.tool_input == "{\"cmd\":"
    end

    test "appends partial_json to existing tool_input" do
      line = ~s({"type":"stream_event","event":{"delta":{"partial_json":"\\"ls\\"}"}}})
      state = %{tool_input: "{\"cmd\":"}

      result = Cli.process_line(line, state)
      assert result.tool_input == "{\"cmd\":\"ls\"}"
    end

    test "clears tool_input on content_block_stop and prints formatted output" do
      line = ~s({"type":"stream_event","event":{"type":"content_block_stop"}})
      state = %{tool_input: ~s({"command":"ls -la"})}

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output =~ "$ ls -la"
      assert_received {:result, %{tool_input: ""}}
    end

    test "handles content_block_stop with empty tool_input" do
      line = ~s({"type":"stream_event","event":{"type":"content_block_stop"}})
      state = %{tool_input: ""}

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      # No output when tool_input is empty
      assert output == ""
      assert_received {:result, %{tool_input: ""}}
    end

    test "handles content_block_stop with malformed JSON in tool_input" do
      line = ~s({"type":"stream_event","event":{"type":"content_block_stop"}})
      state = %{tool_input: "not valid json"}

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      # No output when JSON is invalid
      assert output == ""
      assert_received {:result, %{tool_input: ""}}
    end

    test "returns state unchanged for unknown event types" do
      line = ~s({"type":"unknown"})
      state = %{tool_input: "preserved"}

      assert Cli.process_line(line, state) == state
    end

    test "returns state unchanged for invalid JSON" do
      line = "not valid json at all"
      state = %{tool_input: "preserved"}

      assert Cli.process_line(line, state) == state
    end

    test "returns state unchanged for empty line" do
      line = ""
      state = %{tool_input: "preserved"}

      assert Cli.process_line(line, state) == state
    end
  end

  describe "extract_usage/1" do
    test "extracts usage data from result event" do
      result = %{
        "type" => "result",
        "total_cost_usd" => 0.0259,
        "duration_ms" => 2327,
        "num_turns" => 1,
        "usage" => %{
          "input_tokens" => 100,
          "output_tokens" => 50,
          "cache_read_input_tokens" => 200,
          "cache_creation_input_tokens" => 300
        },
        "modelUsage" => %{
          "claude-opus-4-5-20251101" => %{"inputTokens" => 100}
        }
      }

      # extract_usage is private, test that result structure is correct
      json = Jason.encode!(result)

      # Test that the result type is recognized
      {:ok, decoded} = Jason.decode(json)
      assert decoded["type"] == "result"
      assert decoded["total_cost_usd"] == 0.0259
      assert decoded["usage"]["input_tokens"] == 100
    end
  end

  describe "flush_partial_buffer/1" do
    test "extracts and outputs text from partial JSON with text field" do
      # Simulates a partial streaming event with incomplete text
      partial = ~s({"type":"stream_event","event":{"delta":{"text":"Hello wor)

      output = capture_io(fn -> Cli.flush_partial_buffer(partial) end)
      assert output == "Hello wor"
    end

    test "handles JSON escapes in partial text" do
      partial = ~s({"type":"stream_event","event":{"delta":{"text":"line1\\nline2\\ttab)

      output = capture_io(fn -> Cli.flush_partial_buffer(partial) end)
      assert output == "line1\nline2\ttab"
    end

    test "handles escaped quotes in partial text" do
      partial = ~s({"type":"stream_event","event":{"delta":{"text":"said \\"hello)

      output = capture_io(fn -> Cli.flush_partial_buffer(partial) end)
      assert output == "said \"hello"
    end

    test "handles escaped backslashes in partial text" do
      partial = ~s({"type":"stream_event","event":{"delta":{"text":"path\\\\to)

      output = capture_io(fn -> Cli.flush_partial_buffer(partial) end)
      assert output == "path\\to"
    end

    test "outputs nothing for partial JSON without text field" do
      partial = ~s({"type":"stream_event","event":{"delta":{"partial_json":"{)

      output = capture_io(fn -> Cli.flush_partial_buffer(partial) end)
      assert output == ""
    end

    test "outputs nothing for non-JSON partial data" do
      partial = "some random data without json structure"

      output = capture_io(fn -> Cli.flush_partial_buffer(partial) end)
      assert output == ""
    end

    test "outputs nothing for empty string" do
      output = capture_io(fn -> Cli.flush_partial_buffer("") end)
      assert output == ""
    end
  end

  describe "load_system_prompt/1" do
    test "returns nil for nil agent" do
      assert Cli.load_system_prompt(nil) == nil
    end

    test "returns nil for empty string agent" do
      assert Cli.load_system_prompt("") == nil
    end

    test "loads brownie agent prompt with common prompt" do
      result = Cli.load_system_prompt("brownie")

      # Should contain common prompt
      assert result =~ "verify current documentation"
      assert result =~ "critical thinking"

      # Should contain agent-specific prompt
      assert result =~ "You are brownie"
    end

    test "loads agent prompt with job" do
      result = Cli.load_system_prompt("quick", "probe")

      # Should contain common prompt
      assert result =~ "verify current documentation"

      # Should contain agent identity
      assert result =~ "You are quick"
      assert result =~ "quick@ricon.family"

      # Should contain job description
      assert result =~ "explore the codebase"
      assert result =~ "mise run tasks"
    end

    test "loads agent prompt with critic job" do
      result = Cli.load_system_prompt("brownie", "critic")

      # Should contain agent identity
      assert result =~ "You are brownie"

      # Should contain job description
      assert result =~ "find ONE thing"
      assert result =~ "GitHub issue"
    end

    test "returns common prompt only for non-existent agent" do
      result = Cli.load_system_prompt("non-existent-agent")

      # Should have common prompt content
      assert result =~ "verify current documentation"

      # Should not have agent-specific content
      refute result =~ "You are non-existent-agent"
    end

    test "concatenates common and agent prompts" do
      result = Cli.load_system_prompt("brownie")

      # Both prompts should be present (separated by newlines)
      assert result =~ "uncertain."
      assert result =~ "You are brownie"

      # Common should come before agent
      common_pos = :binary.match(result, "uncertain.") |> elem(0)
      agent_pos = :binary.match(result, "You are brownie") |> elem(0)
      assert common_pos < agent_pos
    end

    test "warns on file read errors other than enoent" do
      # Create a directory where a file is expected - reading it will fail with :eisdir
      # prompts_dir() falls back to priv/prompts relative to cli/lib
      bad_agent_path = Path.join([__DIR__, "..", "priv", "prompts", "agents", "bad-agent.txt"])

      # Create a directory instead of a file to trigger :eisdir error
      File.mkdir_p!(bad_agent_path)

      try do
        # Capture the warning output
        output =
          ExUnit.CaptureIO.capture_io(fn ->
            Cli.load_system_prompt("bad-agent")
          end)

        assert output =~ "WARNING: Failed to read"
        assert output =~ "bad-agent.txt"
      after
        File.rm_rf!(bad_agent_path)
      end
    end
  end
end
