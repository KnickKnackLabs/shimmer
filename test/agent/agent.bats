#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load helpers
}

# --- Workflow template ---

@test "workflow: home preparation delegates to home agent:prepare task" {
  template="$SHIMMER_DIR/.github/templates/agent-run.yml"

  # Parse the YAML structurally so we assert on the step's run: body, not on
  # incidental matches in comments or neighbouring steps.
  run_block=$(yq -r '.jobs.run.steps[] | select(.name == "Prepare home repo") | .run' "$template")

  [ -n "$run_block" ] || {
    echo "could not locate 'Prepare home repo' step in $template" >&2
    return 1
  }

  echo "$run_block" | grep -qF 'mise run agent:prepare'
  ! echo "$run_block" | grep -qF 'rudi install'
  ! echo "$run_block" | grep -qF 'notes unlock'
  ! echo "$run_block" | grep -qF 'modules init'
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

@test "headless: fails without model" {
  setup_agent
  mock_shimmer

  run shimmer agent --headless "do something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires --model"* ]]
}

@test "headless: fails with unqualified model" {
  setup_agent
  mock_shimmer

  run shimmer agent --headless --model "gpt-5.5" "do something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"provider-qualified"* ]]
}

@test "headless: fails when sessions not on PATH" {
  # Skip if sessions is installed — can't reliably hide it from mise subshell
  command -v sessions &>/dev/null && skip "sessions is installed"

  setup_agent
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "do something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sessions not found"* ]]
}

@test "headless: calls sessions new + wake" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "review the PR"
  [ "$status" -eq 0 ]

  # sessions new was called with agent name in session name
  grep -q "^new test-agent-headless-" "$SESSIONS_LOG"
  # sessions new includes agent.name metadata
  grep "^new " "$SESSIONS_LOG" | grep -q "agent.name=test-agent"
  # sessions new does not receive execution-time model selection
  ! grep "^new " "$SESSIONS_LOG" | grep -q -- "--model"
  # sessions wake was called with the session ID from new and explicit model
  grep -q "^wake mock-session-id-001 --headless --message review the PR --model openai-codex/gpt-5.5" "$SESSIONS_LOG"
}

@test "headless: uses SHIV_CALLER_PWD as session cwd before scrubbing" {
  setup_agent
  local caller_dir="$BATS_TEST_TMPDIR/shiv-caller"
  mkdir -p "$caller_dir"
  unset CALLER_PWD
  export SHIV_CALLER_PWD="$caller_dir"
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "review the PR"
  [ "$status" -eq 0 ]

  grep "^new " "$SESSIONS_LOG" | grep -q -- "--cwd $caller_dir"
}

@test "headless: scrubs caller context before invoking sessions" {
  setup_agent
  export SHIV_CALLER_PWD="/stale/shiv/caller"
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "review the PR"
  [ "$status" -eq 0 ]

  grep -q '^CALLER_PWD=$' "$SESSIONS_ENV_LOG"
  grep -q '^SHIV_CALLER_PWD=$' "$SESSIONS_ENV_LOG"
}

@test "headless: session name uses full epoch timestamp" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "test"
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

  run shimmer agent --headless --session "existing-session-42" --model "openai-codex/gpt-5.5" "continue work"
  [ "$status" -eq 0 ]

  # sessions new should NOT be called
  ! grep -q "^new " "$SESSIONS_LOG"
  # sessions wake called with existing session ID
  grep -q "^wake existing-session-42 --headless --message continue work --model openai-codex/gpt-5.5" "$SESSIONS_LOG"
}

@test "headless: forwards model only to sessions wake" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "do something"
  [ "$status" -eq 0 ]

  ! grep "^new " "$SESSIONS_LOG" | grep -q -- "--model openai-codex/gpt-5.5"
  grep "^wake " "$SESSIONS_LOG" | grep -q -- "--model openai-codex/gpt-5.5"
}

@test "headless: timeout stored as metadata (not enforced)" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --timeout 300 --model "openai-codex/gpt-5.5" "do something"
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

@test "interactive: uses SHIV_CALLER_PWD as harness cwd before scrubbing" {
  setup_agent
  local caller_dir="$BATS_TEST_TMPDIR/shiv-caller"
  mkdir -p "$caller_dir"
  unset CALLER_PWD
  export SHIV_CALLER_PWD="$caller_dir"
  mock_harness
  mock_shimmer

  run shimmer agent
  [ "$status" -eq 0 ]

  grep -q "^PWD=$caller_dir$" "$HARNESS_ENV_LOG"
}

@test "interactive: scrubs caller context before invoking harness" {
  setup_agent
  local caller_dir="$BATS_TEST_TMPDIR/scrub-caller"
  mkdir -p "$caller_dir"
  export SHIV_CALLER_PWD="$caller_dir"
  mock_harness
  mock_shimmer

  run shimmer agent
  [ "$status" -eq 0 ]

  grep -q '^CALLER_PWD=$' "$HARNESS_ENV_LOG"
  grep -q '^SHIV_CALLER_PWD=$' "$HARNESS_ENV_LOG"
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

@test "agent:dispatch requires model" {
  mock_gh 12345
  mock_shimmer

  run shimmer agent:dispatch --repo test/repo c0da "hello"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--model"* ]]
}

@test "agent:dispatch requires provider-qualified model" {
  mock_gh 12345
  mock_shimmer

  run shimmer agent:dispatch --repo test/repo --model gpt-5.5 c0da "hello"
  [ "$status" -ne 0 ]
  [[ "$output" == *"provider-qualified"* ]]
}

@test "agent:dispatch preserves embedded newlines in message input" {
  mock_gh 12345
  mock_shimmer

  message=$'line1\nline2'
  run shimmer agent:dispatch --repo test/repo --model openai-codex/gpt-5.5 c0da "$message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Woke c0da (run 12345)"* ]]
  [[ "$output" == *"shimmer ci:logs 12345 --agent --repo test/repo"* ]]
  [[ "$output" != *"actions/runs"* ]]

  log=$(cat "$GH_LOG")
  [[ "$log" == *$'message=line1\nline2'* ]]
  [[ "$log" == *"model=openai-codex/gpt-5.5"* ]]
}
