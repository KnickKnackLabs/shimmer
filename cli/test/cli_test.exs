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

  describe "capture_uncommitted_changes/0" do
    test "function exists and is exported" do
      assert function_exported?(Cli, :capture_uncommitted_changes, 0)
    end

    test "runs without error in a git repository" do
      # This test runs in the actual repo, so it should work
      # We're just verifying it doesn't crash - output goes to stdout
      import ExUnit.CaptureIO
      output = capture_io(fn -> Cli.capture_uncommitted_changes() end)
      assert output =~ "--- UNCOMMITTED CHANGES ---"
      assert output =~ "--- END UNCOMMITTED CHANGES ---"
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
end
