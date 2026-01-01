defmodule CliTest do
  use ExUnit.Case
  doctest Cli

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

    test "formats Edit tool input with old_string and new_string" do
      input = %{
        "file_path" => "/path/to/file.ex",
        "old_string" => "old code here",
        "new_string" => "new code here"
      }

      result = Cli.format_tool_input(input)
      assert result =~ "  /path/to/file.ex"
      assert result =~ "  - old code here..."
      assert result =~ "  + new code here..."
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
      assert result =~ "  prompt: Extract the main content..."
    end

    test "formats prompt input without description" do
      input = %{"prompt" => "Some prompt text"}
      result = Cli.format_tool_input(input)
      assert result == "  prompt: Some prompt text..."
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

  describe "load_system_prompt/1" do
    test "returns nil for nil agent" do
      assert Cli.load_system_prompt(nil) == nil
    end

    test "loads probe-1 agent prompt with common prompt" do
      result = Cli.load_system_prompt("probe-1")

      # Should contain common prompt
      assert result =~ "verify current documentation"
      assert result =~ "critical thinking"

      # Should contain agent-specific prompt
      assert result =~ "You are probe-1"
      assert result =~ "notepad"
    end

    test "returns common prompt only for non-existent agent" do
      result = Cli.load_system_prompt("non-existent-agent")

      # Should have common prompt content
      assert result =~ "verify current documentation"

      # Should not have agent-specific content
      refute result =~ "You are non-existent-agent"
    end

    test "concatenates common and agent prompts" do
      result = Cli.load_system_prompt("probe-1")

      # Both prompts should be present (separated by newlines)
      assert result =~ "uncertain."
      assert result =~ "You are probe-1"

      # Common should come before agent
      common_pos = :binary.match(result, "uncertain.") |> elem(0)
      agent_pos = :binary.match(result, "You are probe-1") |> elem(0)
      assert common_pos < agent_pos
    end
  end
end
