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

  describe "stream event JSON formats" do
    test "text delta format matches expected structure" do
      json = ~s({"type":"stream_event","event":{"delta":{"text":"test output"}}})
      {:ok, decoded} = Jason.decode(json)

      assert decoded["type"] == "stream_event"
      assert decoded["event"]["delta"]["text"] == "test output"
    end

    test "tool use start format matches expected structure" do
      json =
        ~s({"type":"stream_event","event":{"content_block":{"type":"tool_use","name":"Bash"}}})

      {:ok, decoded} = Jason.decode(json)

      assert decoded["type"] == "stream_event"
      assert decoded["event"]["content_block"]["type"] == "tool_use"
      assert decoded["event"]["content_block"]["name"] == "Bash"
    end

    test "partial JSON delta format matches expected structure" do
      json = ~s({"type":"stream_event","event":{"delta":{"partial_json":"{\\"command\\""}}})
      {:ok, decoded} = Jason.decode(json)

      assert decoded["type"] == "stream_event"
      assert decoded["event"]["delta"]["partial_json"] == "{\"command\""
    end

    test "content block stop format matches expected structure" do
      json = ~s({"type":"stream_event","event":{"type":"content_block_stop"}})
      {:ok, decoded} = Jason.decode(json)

      assert decoded["type"] == "stream_event"
      assert decoded["event"]["type"] == "content_block_stop"
    end
  end

  describe "tool input JSON formats" do
    test "Bash command input format" do
      json = ~s({"command":"git status"})
      {:ok, decoded} = Jason.decode(json)

      assert decoded["command"] == "git status"
    end

    test "Read file input format" do
      json = ~s({"file_path":"/path/to/file.ex"})
      {:ok, decoded} = Jason.decode(json)

      assert decoded["file_path"] == "/path/to/file.ex"
    end

    test "Glob pattern input format" do
      json = ~s({"pattern":"**/*.ex"})
      {:ok, decoded} = Jason.decode(json)

      assert decoded["pattern"] == "**/*.ex"
    end

    test "WebFetch input format" do
      json = ~s({"prompt":"Extract the title","description":"Fetch docs"})
      {:ok, decoded} = Jason.decode(json)

      assert decoded["prompt"] == "Extract the title"
      assert decoded["description"] == "Fetch docs"
    end

    test "Edit input format with old and new strings" do
      json = ~s({"file_path":"/path/to/file.ex","old_string":"old","new_string":"new"})
      {:ok, decoded} = Jason.decode(json)

      assert decoded["file_path"] == "/path/to/file.ex"
      assert decoded["old_string"] == "old"
      assert decoded["new_string"] == "new"
    end
  end
end
