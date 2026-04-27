#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load helpers
}

# --- Identity checks ---

@test "headless: fails without GIT_AUTHOR_NAME" {
  unset GIT_AUTHOR_NAME
  export AGENT_IDENTITY="test"
  mock_shimmer

  run shimmer agent --headless "do something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No agent identity"* ]]
}

@test "headless: fails without AGENT_IDENTITY" {
  export GIT_AUTHOR_NAME="test-agent"
  unset AGENT_IDENTITY
  mock_shimmer

  run shimmer agent --headless "do something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"AGENT_IDENTITY not set"* ]]
}

# --- Headless mode ---

@test "headless: fails without message" {
  setup_agent
  mock_shimmer

  run shimmer agent --headless
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires a message"* ]]
}

@test "headless: fails when sessions not on PATH" {
  # Skip if sessions is installed — can't reliably hide it from mise subshell
  command -v sessions &>/dev/null && skip "sessions is installed"

  setup_agent
  mock_shimmer

  run shimmer agent --headless "do something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sessions not found"* ]]
}

@test "headless: calls sessions new + wake" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless "review the PR"
  [ "$status" -eq 0 ]

  # sessions new was called with agent name in session name
  grep -q "^new test-agent-headless-" "$SESSIONS_LOG"
  # sessions new includes agent.name metadata
  grep "^new " "$SESSIONS_LOG" | grep -q "agent.name=test-agent"
  # sessions wake was called with the session ID from new
  grep -q "^wake mock-session-id-001 --headless --message review the PR" "$SESSIONS_LOG"
}

@test "headless: session name uses full epoch timestamp" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless "test"
  [ "$status" -eq 0 ]

  # Extract the session name from the new call — should have full epoch (10+ digits)
  session_name=$(grep "^new " "$SESSIONS_LOG" | awk '{print $2}')
  # Strip prefix to get timestamp portion
  timestamp="${session_name#test-agent-headless-}"
  # Full epoch timestamp is 10 digits (until 2286)
  [ "${#timestamp}" -ge 10 ]
}

@test "headless: resumes existing session (skips sessions new)" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --session "existing-session-42" "continue work"
  [ "$status" -eq 0 ]

  # sessions new should NOT be called
  ! grep -q "^new " "$SESSIONS_LOG"
  # sessions wake called with existing session ID
  grep -q "^wake existing-session-42 --headless --message continue work" "$SESSIONS_LOG"
}

@test "headless: forwards model to sessions new and wake" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "do something"
  [ "$status" -eq 0 ]

  grep "^new " "$SESSIONS_LOG" | grep -q -- "--model openai-codex/gpt-5.5"
  grep "^wake " "$SESSIONS_LOG" | grep -q -- "--model openai-codex/gpt-5.5"
}

@test "headless: timeout stored as metadata (not enforced)" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --timeout 300 "do something"
  [ "$status" -eq 0 ]

  # timeout passed as metadata on wake, not as a flag
  grep "^wake " "$SESSIONS_LOG" | grep -q "timeout=300"
}

# --- Interactive mode ---

@test "interactive: calls harness with agent identity" {
  setup_agent
  mock_harness
  mock_shimmer

  run shimmer agent
  [ "$status" -eq 0 ]

  # harness was called with --append-system-prompt
  grep -q -- "--append-system-prompt" "$HARNESS_LOG"
}

@test "interactive: forwards session flag to harness" {
  setup_agent
  mock_harness
  mock_shimmer

  run shimmer agent --session "/tmp/my-session"
  [ "$status" -eq 0 ]

  grep -q -- "--session /tmp/my-session" "$HARNESS_LOG"
}

@test "interactive: forwards message to harness" {
  setup_agent
  mock_harness
  mock_shimmer

  run shimmer agent "hello there"
  [ "$status" -eq 0 ]

  grep -q "hello there" "$HARNESS_LOG"
}

@test "agent:dispatch preserves embedded newlines in message input" {
  mock_gh 12345
  mock_shimmer

  message=$'line1\nline2'
  run shimmer agent:dispatch --repo test/repo c0da "$message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Woke c0da (run 12345)"* ]]

  log=$(cat "$GH_LOG")
  [[ "$log" == *$'message=line1\nline2'* ]]
}
