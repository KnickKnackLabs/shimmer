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
      assert output =~ "WARNING: Unknown argument ignored: --agnet"
    end

    test "warns about multiple unknown arguments" do
      {output, _exit_code} = run_cli(["--agnet", "quick", "--tiemout", "60"])
      assert output =~ "WARNING: Unknown argument ignored: --agnet"
      assert output =~ "WARNING: Unknown argument ignored: --tiemout"
    end

    test "no warning for valid arguments" do
      {output, _exit_code} = run_cli(["--agent", "quick", "--timeout", "60"])
      refute output =~ "WARNING: Unknown argument"
    end

    test "shows specific error for non-integer timeout value" do
      {output, _exit_code} = run_cli(["--agent", "quick", "--timeout", "abc", "hello"])
      assert output =~ "ERROR: --timeout requires an integer value, got: abc"
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

    test "requires system-prompt-file" do
      {output, exit_code} = run_cli(["--timeout", "60", "hello"])
      assert exit_code == 1
      assert output =~ "--system-prompt-file is required"
    end

    test "rejects non-existent system-prompt-file" do
      {output, exit_code} =
        run_cli(["--system-prompt-file", "/nonexistent/path.txt", "--timeout", "60", "hello"])

      assert exit_code == 1
      assert output =~ "System prompt file not found"
    end
  end

  describe "Cli module" do
    test "exports main/1 function" do
      assert function_exported?(Cli, :main, 1)
    end

    test "module loads without errors" do
      assert Code.ensure_loaded?(Cli)
    end
  end

  describe "JSON parsing" do
    test "pi text_delta event parses correctly" do
      json =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{"type" => "text_delta", "delta" => "Hello"}
        })

      {:ok, decoded} = Jason.decode(json)
      assert decoded["type"] == "message_update"
      assert get_in(decoded, ["assistantMessageEvent", "delta"]) == "Hello"
    end

    test "JSON parsing handles malformed input" do
      result = Jason.decode("not valid json")
      assert {:error, _} = result
    end
  end

  describe "format_tool_input/1" do
    test "formats bash command input" do
      input = %{"command" => "ls -la"}
      assert Cli.format_tool_input(input) == "  $ ls -la"
    end

    test "formats pi read/write tool input with path" do
      input = %{"path" => "/path/to/file.ex"}
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

    test "formats pi edit tool input with edits array" do
      input = %{
        "path" => "/path/to/file.ex",
        "edits" => [%{"oldText" => "old code here", "newText" => "new code here"}]
      }

      result = Cli.format_tool_input(input)
      assert result =~ "  /path/to/file.ex"
      assert result =~ "  - old code here"
      assert result =~ "  + new code here"
      refute result =~ "old code here..."
      refute result =~ "new code here..."
    end

    test "truncates long oldText and newText in pi edit tool" do
      long_string = String.duplicate("x", 100)

      input = %{
        "path" => "/path/to/file.ex",
        "edits" => [%{"oldText" => long_string, "newText" => long_string}]
      }

      result = Cli.format_tool_input(input)
      assert result =~ String.duplicate("x", 60) <> "..."
    end

    test "replaces newlines in pi edit tool strings" do
      input = %{
        "path" => "/path/to/file.ex",
        "edits" => [%{"oldText" => "line1\nline2", "newText" => "line3\nline4"}]
      }

      result = Cli.format_tool_input(input)
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

      result = Cli.format_tool_input(input)
      assert result == "  2 todo(s): First task"
    end

    test "formats TodoWrite tool input with empty todos list" do
      input = %{"todos" => []}

      result = Cli.format_tool_input(input)
      assert result == "  0 todo(s)"
    end

    test "handles TodoWrite with non-map todo items gracefully" do
      input = %{"todos" => ["Task 1", "Task 2"]}

      result = Cli.format_tool_input(input)
      assert result == "  2 todo(s)"
    end

    test "handles TodoWrite with mixed todo items gracefully" do
      input = %{"todos" => [nil, %{"content" => "Valid task"}]}

      result = Cli.format_tool_input(input)
      assert result == "  2 todo(s)"
    end

    test "formats WebFetch tool input with prompt" do
      input = %{
        "prompt" => "Extract the main content",
        "description" => "Fetching docs"
      }

      result = Cli.format_tool_input(input)
      assert result =~ "  Fetching docs"
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
      assert result =~ "  prompt: Extract the main content"
      refute result =~ "Extract the main content..."
    end

    test "formats WebFetch tool input with url but no description" do
      input = %{
        "url" => "https://example.com",
        "prompt" => "Get content"
      }

      result = Cli.format_tool_input(input)
      assert result == "  url: https://example.com\n  prompt: Get content"
    end

    test "formats WebFetch tool input with url and empty description" do
      input = %{
        "url" => "https://example.com",
        "prompt" => "Get content",
        "description" => ""
      }

      result = Cli.format_tool_input(input)
      assert result == "  url: https://example.com\n  prompt: Get content"
    end

    test "formats prompt input without description" do
      input = %{"prompt" => "Some prompt text"}
      result = Cli.format_tool_input(input)
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

  describe "process_line/2 — pi text events" do
    test "outputs text delta and tracks abort_seen" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{"type" => "text_delta", "delta" => "Hello"}
        })

      state = %{
        tool_input: "",
        abort_seen: false,
        recent_text: "",
        flushed_chars: 0,
        had_newline_before_window: true
      }

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output == "Hello"

      assert_received {:result,
                       %{
                         tool_input: "",
                         abort_seen: false,
                         recent_text: "Hello",
                         flushed_chars: 0
                       }}
    end

    test "detects [[ABORT]] on its own line" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{"type" => "text_delta", "delta" => "[[ABORT]]\n"}
        })

      state = %{
        tool_input: "",
        abort_seen: false,
        recent_text: "",
        flushed_chars: 0,
        had_newline_before_window: true
      }

      capture_io(fn ->
        result = Cli.process_line(line, state)
        send(self(), {:result, result})
      end)

      assert_received {:result, %{abort_seen: true}}
    end

    test "detects [[ABORT]] split across streaming chunks" do
      line1 =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{"type" => "text_delta", "delta" => "[[ABO"}
        })

      state1 = %{
        tool_input: "",
        abort_seen: false,
        recent_text: "",
        flushed_chars: 0,
        had_newline_before_window: true
      }

      capture_io(fn ->
        result = Cli.process_line(line1, state1)
        send(self(), {:result1, result})
      end)

      assert_received {:result1, %{abort_seen: false} = state2}

      line2 =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{"type" => "text_delta", "delta" => "RT]]\n"}
        })

      capture_io(fn ->
        result = Cli.process_line(line2, state2)
        send(self(), {:result2, result})
      end)

      assert_received {:result2, %{abort_seen: true}}
    end

    test "detects [[ABORT]] split across chunks when followed by long text" do
      line1 =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{"type" => "text_delta", "delta" => "prefix\n[[ABO"}
        })

      state1 = %{
        tool_input: "",
        abort_seen: false,
        recent_text: "",
        flushed_chars: 0,
        had_newline_before_window: true
      }

      capture_io(fn ->
        result = Cli.process_line(line1, state1)
        send(self(), {:result1, result})
      end)

      assert_received {:result1, %{abort_seen: false} = state2}

      line2 =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{
            "type" => "text_delta",
            "delta" => "RT]]\nlots of additional text that pushes it out of window"
          }
        })

      capture_io(fn ->
        result = Cli.process_line(line2, state2)
        send(self(), {:result2, result})
      end)

      assert_received {:result2, %{abort_seen: true}}
    end

    test "detects [[ABORT]] after >20 chars of text ending with newline" do
      line1 =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{
            "type" => "text_delta",
            "delta" => "aaaaaaaaaaaaaaaaaaaaaaa\n"
          }
        })

      state1 = %{
        tool_input: "",
        abort_seen: false,
        recent_text: "",
        flushed_chars: 0,
        had_newline_before_window: true
      }

      capture_io(fn ->
        result = Cli.process_line(line1, state1)
        send(self(), {:result1, result})
      end)

      assert_received {:result1, %{abort_seen: false} = state2}

      line2 =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{"type" => "text_delta", "delta" => "[[ABORT]]\n"}
        })

      capture_io(fn ->
        result = Cli.process_line(line2, state2)
        send(self(), {:result2, result})
      end)

      assert_received {:result2, %{abort_seen: true}}
    end

    test "does not detect [[ABORT]] embedded in text" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{
            "type" => "text_delta",
            "delta" => "some [[ABORT]] text"
          }
        })

      state = %{
        tool_input: "",
        abort_seen: false,
        recent_text: "",
        flushed_chars: 0,
        had_newline_before_window: true
      }

      capture_io(fn ->
        result = Cli.process_line(line, state)
        send(self(), {:result, result})
      end)

      assert_received {:result, %{abort_seen: false}}
    end

    test "skips already-flushed text prefix" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{"type" => "text_delta", "delta" => "Hello world"}
        })

      state = %{
        tool_input: "",
        abort_seen: false,
        recent_text: "",
        flushed_chars: 9,
        had_newline_before_window: true
      }

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output == "ld"
      assert_received {:result, %{flushed_chars: 0}}
    end

    test "outputs full text when flushed_chars is zero" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{"type" => "text_delta", "delta" => "Hello world"}
        })

      state = %{
        tool_input: "",
        abort_seen: false,
        recent_text: "",
        flushed_chars: 0,
        had_newline_before_window: true
      }

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output == "Hello world"
    end

    test "outputs remaining text when flushed_chars exceeds text length" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{"type" => "text_delta", "delta" => "Hi"}
        })

      state = %{
        tool_input: "",
        abort_seen: false,
        recent_text: "",
        flushed_chars: 10,
        had_newline_before_window: true
      }

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output == ""
    end
  end

  describe "process_line/2 — pi tool events" do
    test "resets tool_input on toolcall_start and prints tool name" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{
            "type" => "toolcall_start",
            "contentIndex" => 1,
            "partial" => %{
              "content" => [
                %{"type" => "text", "text" => "I'll run that."},
                %{"type" => "toolCall", "name" => "bash", "arguments" => %{}}
              ]
            }
          }
        })

      state = %{tool_input: "leftover"}

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output =~ "[TOOL] bash"
      assert_received {:result, %{tool_input: ""}}
    end

    test "accumulates toolcall_delta to tool_input" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{
            "type" => "toolcall_delta",
            "delta" => ~s({"command": "ls)
          }
        })

      state = %{tool_input: ""}
      result = Cli.process_line(line, state)
      assert result.tool_input == ~s({"command": "ls)
    end

    test "ignores empty toolcall_delta" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{
            "type" => "toolcall_delta",
            "delta" => ""
          }
        })

      state = %{tool_input: "existing"}
      result = Cli.process_line(line, state)
      # Empty delta should not change state (falls through to _ catch-all)
      assert result.tool_input == "existing"
    end

    test "appends toolcall_delta to existing tool_input" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{
            "type" => "toolcall_delta",
            "delta" => ~s( -la"})
          }
        })

      state = %{tool_input: ~s({"command": "ls)}
      result = Cli.process_line(line, state)
      assert result.tool_input == ~s({"command": "ls -la"})
    end

    test "clears tool_input on toolcall_end and prints formatted output" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{
            "type" => "toolcall_end",
            "toolCall" => %{
              "name" => "bash",
              "arguments" => %{"command" => "ls -la"}
            }
          }
        })

      state = %{tool_input: ~s({"command":"ls -la"})}

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output =~ "$ ls -la"
      assert_received {:result, %{tool_input: ""}}
    end

    test "handles toolcall_end with no arguments" do
      line =
        Jason.encode!(%{
          "type" => "message_update",
          "assistantMessageEvent" => %{
            "type" => "toolcall_end",
            "toolCall" => %{"name" => "bash"}
          }
        })

      state = %{tool_input: ""}

      output =
        capture_io(fn ->
          result = Cli.process_line(line, state)
          send(self(), {:result, result})
        end)

      assert output == ""
      assert_received {:result, %{tool_input: ""}}
    end
  end

  describe "process_line/2 — pi agent_end" do
    test "extracts usage data from agent_end event" do
      line =
        Jason.encode!(%{
          "type" => "agent_end",
          "messages" => [
            %{"role" => "user", "content" => [%{"type" => "text", "text" => "hello"}]},
            %{
              "role" => "assistant",
              "content" => [%{"type" => "text", "text" => "Hi!"}],
              "usage" => %{
                "input" => 100,
                "output" => 50,
                "cacheRead" => 200,
                "cacheWrite" => 300,
                "cost" => %{"total" => 0.0259}
              }
            }
          ]
        })

      state = %{tool_input: "", usage: nil}
      result_state = Cli.process_line(line, state)

      assert result_state.usage.cost_usd == 0.0259
      assert result_state.usage.num_turns == 1
      assert result_state.usage.usage["input_tokens"] == 100
      assert result_state.usage.usage["output_tokens"] == 50
      assert result_state.usage.usage["cache_read_input_tokens"] == 200
      assert result_state.usage.usage["cache_creation_input_tokens"] == 300
    end

    test "sums usage across multiple assistant messages" do
      line =
        Jason.encode!(%{
          "type" => "agent_end",
          "messages" => [
            %{"role" => "user", "content" => []},
            %{
              "role" => "assistant",
              "usage" => %{
                "input" => 100,
                "output" => 50,
                "cacheRead" => 200,
                "cacheWrite" => 0,
                "cost" => %{"total" => 0.01}
              }
            },
            %{"role" => "toolResult", "content" => []},
            %{
              "role" => "assistant",
              "usage" => %{
                "input" => 80,
                "output" => 30,
                "cacheRead" => 250,
                "cacheWrite" => 100,
                "cost" => %{"total" => 0.005}
              }
            }
          ]
        })

      state = %{tool_input: "", usage: nil}
      result_state = Cli.process_line(line, state)

      assert result_state.usage.cost_usd == 0.015
      assert result_state.usage.num_turns == 2
      assert result_state.usage.usage["input_tokens"] == 180
      assert result_state.usage.usage["output_tokens"] == 80
      assert result_state.usage.usage["cache_read_input_tokens"] == 450
      assert result_state.usage.usage["cache_creation_input_tokens"] == 100
    end
  end

  describe "process_line/2 — general" do
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

    test "ignores pi session/turn/message_start events" do
      for type <- ["session", "agent_start", "turn_start", "turn_end"] do
        line = Jason.encode!(%{"type" => type})
        state = %{tool_input: "preserved"}
        assert Cli.process_line(line, state) == state
      end
    end
  end

  describe "flush_partial_buffer/1" do
    test "extracts and outputs text from partial pi text_delta event" do
      partial =
        ~s({"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"Hello wor)

      output = capture_io(fn -> Cli.flush_partial_buffer(partial) end)
      assert output == "Hello wor"
    end

    test "handles JSON escapes in partial text" do
      partial =
        ~s({"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"line1\\nline2\\ttab)

      output = capture_io(fn -> Cli.flush_partial_buffer(partial) end)
      assert output == "line1\nline2\ttab"
    end

    test "outputs nothing for partial JSON without delta field" do
      partial =
        ~s({"type":"message_update","assistantMessageEvent":{"type":"toolcall_start","contentIndex":1)

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

  describe "extract_partial_text/1" do
    test "extracts text from partial pi text_delta event" do
      partial =
        ~s({"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"Hello wor)

      assert Cli.extract_partial_text(partial) == "Hello wor"
    end

    test "handles JSON escapes" do
      partial =
        ~s({"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"line1\\nline2\\ttab)

      assert Cli.extract_partial_text(partial) == "line1\nline2\ttab"
    end

    test "returns empty string for non-delta partial" do
      partial = ~s({"type":"session","version":3,"id":"abc)
      assert Cli.extract_partial_text(partial) == ""
    end

    test "returns empty string for non-JSON" do
      assert Cli.extract_partial_text("random data") == ""
    end

    test "returns empty string for empty input" do
      assert Cli.extract_partial_text("") == ""
    end
  end

  describe "text_beyond_flushed/2" do
    test "returns remainder after flushed chars" do
      assert Cli.text_beyond_flushed("hello world", 5) == " world"
    end

    test "returns empty string when fully flushed" do
      assert Cli.text_beyond_flushed("hello", 5) == ""
    end

    test "returns full text when flushed_chars is zero" do
      assert Cli.text_beyond_flushed("hello", 0) == "hello"
    end

    test "returns empty string when flushed_chars exceeds text length" do
      assert Cli.text_beyond_flushed("different", 10) == ""
    end

    test "handles empty text" do
      assert Cli.text_beyond_flushed("", 0) == ""
      assert Cli.text_beyond_flushed("", 5) == ""
    end

    test "raises on nil flushed_chars (type safety)" do
      assert_raise FunctionClauseError, fn ->
        Cli.text_beyond_flushed("hello world", nil)
      end
    end
  end
end
