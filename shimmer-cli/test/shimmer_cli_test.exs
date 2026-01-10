defmodule ShimmerCliTest do
  use ExUnit.Case
  doctest ShimmerCli
  import ExUnit.CaptureIO

  # Helper to capture both IO output and return value from ShimmerCli.run
  defp run_cli(args) do
    output =
      capture_io(fn ->
        send(self(), {:result, ShimmerCli.run(args)})
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

    test "returns exit code 1 for whitespace-only message" do
      whitespace_cases = ["   ", "\t\t", "\n\n", "  \t\n  "]

      for ws <- whitespace_cases do
        {output, exit_code} = run_cli(["--agent", "quick", "--timeout", "60", ws])
        assert exit_code == 1, "Expected exit 1 for whitespace: #{inspect(ws)}"
        assert output =~ "No message provided"
      end
    end

    test "rejects agent name with path traversal characters" do
      {output, exit_code} =
        run_cli(["--agent", "../../../etc/passwd", "--timeout", "60", "hello"])

      assert exit_code == 1

      assert output =~
               "--agent must contain only alphanumeric characters, hyphens, and underscores"
    end

    test "rejects agent name with dots" do
      {output, exit_code} = run_cli(["--agent", "agent.with.dots", "--timeout", "60", "hello"])
      assert exit_code == 1

      assert output =~
               "--agent must contain only alphanumeric characters, hyphens, and underscores"
    end

    test "rejects agent name with slashes" do
      {output, exit_code} = run_cli(["--agent", "agent/with/slashes", "--timeout", "60", "hello"])
      assert exit_code == 1

      assert output =~
               "--agent must contain only alphanumeric characters, hyphens, and underscores"
    end

    test "rejects job name with path traversal characters" do
      {output, exit_code} =
        run_cli(["--agent", "quick", "--job", "../../evil", "--timeout", "60", "hello"])

      assert exit_code == 1
      assert output =~ "--job must contain only alphanumeric characters, hyphens, and underscores"
    end
  end

  describe "ShimmerCli module" do
    test "exports main/1 function" do
      # Verify the main entry point exists
      assert function_exported?(ShimmerCli, :main, 1)
    end

    test "module loads without errors" do
      # Basic smoke test - if this passes, the module compiles correctly
      assert Code.ensure_loaded?(ShimmerCli)
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
      assert ShimmerCli.format_tool_input(input) == "  $ ls -la"
    end

    test "formats file path input for Read tool" do
      input = %{"file_path" => "/path/to/file.ex"}
      assert ShimmerCli.format_tool_input(input) == "  -> /path/to/file.ex"
    end

    test "formats pattern input for Glob tool" do
      input = %{"pattern" => "**/*.ex"}
      assert ShimmerCli.format_tool_input(input) == "  pattern: **/*.ex"
    end

    test "formats pattern input for Grep tool with path" do
      input = %{"pattern" => "def main", "path" => "cli/lib/cli.ex"}
      assert ShimmerCli.format_tool_input(input) == "  cli/lib/cli.ex\n  pattern: def main"
    end

    test "formats Edit tool input with old_string and new_string" do
      input = %{
        "file_path" => "/path/to/file.ex",
        "old_string" => "old code here",
        "new_string" => "new code here"
      }

      result = ShimmerCli.format_tool_input(input)
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

      result = ShimmerCli.format_tool_input(input)
      # Should truncate to 60 chars plus "..."
      assert result =~ String.duplicate("x", 60) <> "..."
    end

    test "replaces newlines in Edit tool strings" do
      input = %{
        "file_path" => "/path/to/file.ex",
        "old_string" => "line1\nline2",
        "new_string" => "line3\nline4"
      }

      result = ShimmerCli.format_tool_input(input)
      assert result =~ "line1\\nline2"
      assert result =~ "line3\\nline4"
    end

    test "formats TodoWrite tool input with map todos" do
      input = %{
        "todos" => [
          %{"content" => "First task", "status" => "in_progress", "activeForm" => "Doing first"},
          %{"content" => "Second task", "status" => "pending", "activeForm" => "Doing second"}
        ]
      }

      result = ShimmerCli.format_tool_input(input)
      assert result == "  2 todo(s): First task"
    end

    test "formats TodoWrite tool input with empty todos list" do
      input = %{"todos" => []}

      result = ShimmerCli.format_tool_input(input)
      assert result == "  0 todo(s)"
    end

    test "handles TodoWrite with non-map todo items gracefully" do
      # Edge case: model sends malformed data (strings instead of maps)
      input = %{"todos" => ["Task 1", "Task 2"]}

      result = ShimmerCli.format_tool_input(input)
      # Should not crash, just show count without preview
      assert result == "  2 todo(s)"
    end

    test "handles TodoWrite with mixed todo items gracefully" do
      # Edge case: some items are maps, some are not
      input = %{"todos" => [nil, %{"content" => "Valid task"}]}

      result = ShimmerCli.format_tool_input(input)
      # First item is nil, so no preview
      assert result == "  2 todo(s)"
    end

    test "formats WebFetch tool input with prompt" do
      input = %{
        "prompt" => "Extract the main content",
        "description" => "Fetching docs"
      }

      result = ShimmerCli.format_tool_input(input)
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

      result = ShimmerCli.format_tool_input(input)
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

      result = ShimmerCli.format_tool_input(input)
      # Should not have leading empty line when description is missing
      assert result == "  url: https://example.com\n  prompt: Get content"
    end

    test "formats WebFetch tool input with url and empty description" do
      input = %{
        "url" => "https://example.com",
        "prompt" => "Get content",
        "description" => ""
      }

      result = ShimmerCli.format_tool_input(input)
      # Should not have leading empty line when description is empty
      assert result == "  url: https://example.com\n  prompt: Get content"
    end

    test "formats prompt input without description" do
      input = %{"prompt" => "Some prompt text"}
      result = ShimmerCli.format_tool_input(input)
      # Short prompts should NOT have ellipsis
      assert result == "  prompt: Some prompt text"
      refute result =~ "Some prompt text..."
    end

    test "truncates long prompts to 100 chars" do
      long_prompt = String.duplicate("a", 150)
      input = %{"prompt" => long_prompt}

      result = ShimmerCli.format_tool_input(input)
      assert result =~ String.duplicate("a", 100) <> "..."
      refute result =~ String.duplicate("a", 101)
    end

    test "returns nil for unrecognized input format" do
      assert ShimmerCli.format_tool_input(%{"unknown" => "value"}) == nil
      assert ShimmerCli.format_tool_input(%{}) == nil
    end
  end

  describe "process_line/2" do
    test "outputs text delta and tracks abort_seen" do
      line = ~s({"type":"stream_event","event":{"delta":{"text":"Hello"}}})
      state = %{tool_input: "", abort_seen: false, recent_text: "", flushed_text: ""}

      output =
        capture_io(fn ->
          result = ShimmerCli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output == "Hello"

      assert_received {:result,
                       %{
                         tool_input: "",
                         abort_seen: false,
                         recent_text: "Hello",
                         flushed_text: ""
                       }}
    end

    test "detects [[ABORT]] on its own line" do
      line = ~s({"type":"stream_event","event":{"delta":{"text":"[[ABORT]]\\n"}}})
      state = %{tool_input: "", abort_seen: false, recent_text: "", flushed_text: ""}

      capture_io(fn ->
        result = ShimmerCli.process_line(line, state)
        send(self(), {:result, result})
      end)

      assert_received {:result, %{abort_seen: true}}
    end

    test "detects [[ABORT]] split across streaming chunks" do
      # First chunk ends mid-signal
      line1 = ~s({"type":"stream_event","event":{"delta":{"text":"[[ABO"}}})
      state1 = %{tool_input: "", abort_seen: false, recent_text: "", flushed_text: ""}

      capture_io(fn ->
        result = ShimmerCli.process_line(line1, state1)
        send(self(), {:result1, result})
      end)

      assert_received {:result1, %{abort_seen: false, recent_text: _recent} = state2}

      # Second chunk completes the signal
      line2 = ~s({"type":"stream_event","event":{"delta":{"text":"RT]]\\n"}}})

      capture_io(fn ->
        result = ShimmerCli.process_line(line2, state2)
        send(self(), {:result2, result})
      end)

      assert_received {:result2, %{abort_seen: true}}
    end

    test "does not detect [[ABORT]] embedded in text" do
      line = ~s({"type":"stream_event","event":{"delta":{"text":"some [[ABORT]] text"}}})
      state = %{tool_input: "", abort_seen: false, recent_text: "", flushed_text: ""}

      capture_io(fn ->
        result = ShimmerCli.process_line(line, state)
        send(self(), {:result, result})
      end)

      assert_received {:result, %{abort_seen: false}}
    end

    test "skips already-flushed text prefix" do
      # Simulates the scenario from issue #338:
      # 1. Partial buffer was flushed showing "Hello wor"
      # 2. Full line completes with "Hello world"
      # 3. Should only output "ld" (the new part)
      line = ~s({"type":"stream_event","event":{"delta":{"text":"Hello world"}}})
      state = %{tool_input: "", abort_seen: false, recent_text: "", flushed_text: "Hello wor"}

      output =
        capture_io(fn ->
          result = ShimmerCli.process_line(line, state)
          send(self(), {:result, result})
        end)

      # Should only output the new part
      assert output == "ld"
      # flushed_text should be reset after processing complete line
      assert_received {:result, %{flushed_text: ""}}
    end

    test "outputs full text when flushed_text is empty" do
      line = ~s({"type":"stream_event","event":{"delta":{"text":"Hello world"}}})
      state = %{tool_input: "", abort_seen: false, recent_text: "", flushed_text: ""}

      output =
        capture_io(fn ->
          result = ShimmerCli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output == "Hello world"
    end

    test "outputs full text when flushed_text does not match prefix" do
      # Edge case: flushed text doesn't match the complete text
      # (shouldn't happen in practice, but handle gracefully)
      line = ~s({"type":"stream_event","event":{"delta":{"text":"Different text"}}})
      state = %{tool_input: "", abort_seen: false, recent_text: "", flushed_text: "Hello"}

      output =
        capture_io(fn ->
          result = ShimmerCli.process_line(line, state)
          send(self(), {:result, result})
        end)

      # Should output the full text since flushed doesn't match
      assert output == "Different text"
    end

    test "resets tool_input on tool_use start and prints tool name" do
      line =
        ~s({"type":"stream_event","event":{"content_block":{"type":"tool_use","name":"Bash"}}})

      state = %{tool_input: "leftover"}

      output =
        capture_io(fn ->
          result = ShimmerCli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output =~ "[TOOL] Bash"
      assert_received {:result, %{tool_input: ""}}
    end

    test "accumulates partial_json to tool_input" do
      line = ~s({"type":"stream_event","event":{"delta":{"partial_json":"{\\"cmd\\":"}}})
      state = %{tool_input: ""}

      result = ShimmerCli.process_line(line, state)
      assert result.tool_input == "{\"cmd\":"
    end

    test "appends partial_json to existing tool_input" do
      line = ~s({"type":"stream_event","event":{"delta":{"partial_json":"\\"ls\\"}"}}})
      state = %{tool_input: "{\"cmd\":"}

      result = ShimmerCli.process_line(line, state)
      assert result.tool_input == "{\"cmd\":\"ls\"}"
    end

    test "clears tool_input on content_block_stop and prints formatted output" do
      line = ~s({"type":"stream_event","event":{"type":"content_block_stop"}})
      state = %{tool_input: ~s({"command":"ls -la"})}

      output =
        capture_io(fn ->
          result = ShimmerCli.process_line(line, state)
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
          result = ShimmerCli.process_line(line, state)
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
          result = ShimmerCli.process_line(line, state)
          send(self(), {:result, result})
        end)

      # No output when JSON is invalid
      assert output == ""
      assert_received {:result, %{tool_input: ""}}
    end

    test "returns state unchanged for unknown event types" do
      line = ~s({"type":"unknown"})
      state = %{tool_input: "preserved"}

      assert ShimmerCli.process_line(line, state) == state
    end

    test "returns state unchanged for invalid JSON" do
      line = "not valid json at all"
      state = %{tool_input: "preserved"}

      assert ShimmerCli.process_line(line, state) == state
    end

    test "returns state unchanged for empty line" do
      line = ""
      state = %{tool_input: "preserved"}

      assert ShimmerCli.process_line(line, state) == state
    end
  end

  describe "result event processing" do
    test "extracts usage data from result event" do
      line =
        Jason.encode!(%{
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
        })

      state = %{tool_input: "", full_text: "", usage: nil}
      result_state = ShimmerCli.process_line(line, state)

      assert result_state.usage.cost_usd == 0.0259
      assert result_state.usage.duration_ms == 2327
      assert result_state.usage.num_turns == 1
      assert result_state.usage.usage["input_tokens"] == 100
      assert result_state.usage.usage["output_tokens"] == 50
      assert result_state.usage.model_usage["claude-opus-4-5-20251101"]["inputTokens"] == 100
    end
  end

  describe "flush_partial_buffer/1" do
    test "extracts and outputs text from partial JSON with text field" do
      # Simulates a partial streaming event with incomplete text
      partial = ~s({"type":"stream_event","event":{"delta":{"text":"Hello wor)

      output = capture_io(fn -> ShimmerCli.flush_partial_buffer(partial) end)
      assert output == "Hello wor"
    end

    # Verifies regex captures escape sequences and Jason decodes them.
    # Jason handles all standard JSON escapes: \n, \t, \r, \", \\, \b, \f, \/, \uXXXX
    test "handles JSON escapes in partial text" do
      partial = ~s({"type":"stream_event","event":{"delta":{"text":"line1\\nline2\\ttab)

      output = capture_io(fn -> ShimmerCli.flush_partial_buffer(partial) end)
      assert output == "line1\nline2\ttab"
    end

    test "outputs nothing for partial JSON without text field" do
      partial = ~s({"type":"stream_event","event":{"delta":{"partial_json":"{)

      output = capture_io(fn -> ShimmerCli.flush_partial_buffer(partial) end)
      assert output == ""
    end

    test "outputs nothing for non-JSON partial data" do
      partial = "some random data without json structure"

      output = capture_io(fn -> ShimmerCli.flush_partial_buffer(partial) end)
      assert output == ""
    end

    test "outputs nothing for empty string" do
      output = capture_io(fn -> ShimmerCli.flush_partial_buffer("") end)
      assert output == ""
    end
  end

  describe "extract_partial_text/1" do
    test "extracts text from partial JSON" do
      partial = ~s({"type":"stream_event","event":{"delta":{"text":"Hello wor)
      assert ShimmerCli.extract_partial_text(partial) == "Hello wor"
    end

    test "handles JSON escapes" do
      partial = ~s({"type":"stream_event","event":{"delta":{"text":"line1\\nline2\\ttab)
      assert ShimmerCli.extract_partial_text(partial) == "line1\nline2\ttab"
    end

    test "returns empty string for non-text partial" do
      partial = ~s({"type":"stream_event","event":{"delta":{"partial_json":"{)
      assert ShimmerCli.extract_partial_text(partial) == ""
    end

    test "returns empty string for non-JSON" do
      assert ShimmerCli.extract_partial_text("random data") == ""
    end

    test "returns empty string for empty input" do
      assert ShimmerCli.extract_partial_text("") == ""
    end
  end

  describe "text_beyond_flushed/2" do
    test "returns remainder when flushed matches prefix" do
      assert ShimmerCli.text_beyond_flushed("hello world", "hello") == " world"
    end

    test "returns empty string when fully flushed" do
      assert ShimmerCli.text_beyond_flushed("hello", "hello") == ""
    end

    test "returns full text when flushed is empty" do
      assert ShimmerCli.text_beyond_flushed("hello", "") == "hello"
    end

    test "returns full text when flushed does not match prefix" do
      assert ShimmerCli.text_beyond_flushed("different", "hello") == "different"
    end

    test "handles empty text" do
      assert ShimmerCli.text_beyond_flushed("", "") == ""
      assert ShimmerCli.text_beyond_flushed("", "flushed") == ""
    end
  end

  describe "load_system_prompt/1" do
    test "returns nil for nil agent" do
      assert ShimmerCli.load_system_prompt(nil) == nil
    end

    test "returns nil for empty string agent" do
      assert ShimmerCli.load_system_prompt("") == nil
    end

    test "loads brownie agent prompt with common prompt" do
      result = ShimmerCli.load_system_prompt("brownie")

      # Should contain common prompt
      assert result =~ "verify current documentation"
      assert result =~ "critical thinking"

      # Should contain agent-specific prompt
      assert result =~ "You are brownie"
    end

    test "loads agent prompt with job" do
      result = ShimmerCli.load_system_prompt("quick", "probe")

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
      result = ShimmerCli.load_system_prompt("brownie", "critic")

      # Should contain agent identity
      assert result =~ "You are brownie"

      # Should contain job description
      assert result =~ "find ONE thing"
      assert result =~ "GitHub issue"
    end

    test "returns common prompt only for non-existent agent with warning" do
      import ExUnit.CaptureIO

      {result, output} =
        with_io(fn ->
          ShimmerCli.load_system_prompt("non-existent-agent")
        end)

      # Should have common prompt content
      assert result =~ "verify current documentation"

      # Should not have agent-specific content
      refute result =~ "You are non-existent-agent"

      # Should warn about missing agent prompt with available agents listed
      assert output =~ "WARNING: Agent prompt not found: non-existent-agent.txt"
      assert output =~ "Available: brownie"
    end

    test "concatenates common and agent prompts" do
      result = ShimmerCli.load_system_prompt("brownie")

      # Both prompts should be present (separated by newlines)
      assert result =~ "uncertain."
      assert result =~ "You are brownie"

      # Common should come before agent
      common_pos = :binary.match(result, "uncertain.") |> elem(0)
      agent_pos = :binary.match(result, "You are brownie") |> elem(0)
      assert common_pos < agent_pos
    end

    test "warns on non-existent job prompt" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          ShimmerCli.load_system_prompt("brownie", "non-existent-job")
        end)

      # Should warn about missing job prompt with available jobs listed
      assert output =~ "WARNING: Job prompt not found: non-existent-job.txt"
      assert output =~ "Available:"
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
            ShimmerCli.load_system_prompt("bad-agent")
          end)

        assert output =~ "WARNING: Failed to read"
        assert output =~ "bad-agent.txt"
      after
        File.rm_rf!(bad_agent_path)
      end
    end
  end
end
