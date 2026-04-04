#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load helpers.bash

# --- Setup: seed telemetry file with events ---

setup() {
  export TELEMETRY_FILE="$BATS_TEST_TMPDIR/telemetry-$$.jsonl"
  unset TELEMETRY_HOOK
  mock_shimmer

  # Seed events
  shimmer telemetry:emit '{"ts":"2026-04-01T10:00:00Z","tool":"queue","cmd":"list","items":5}'
  shimmer telemetry:emit '{"ts":"2026-04-01T11:00:00Z","tool":"chat","cmd":"read","messages":3}'
  shimmer telemetry:emit '{"ts":"2026-04-02T10:00:00Z","tool":"queue","cmd":"peek","items":1}'
  shimmer telemetry:emit '{"ts":"2026-04-02T11:00:00Z","tool":"threads","cmd":"list","threads":12}'
  shimmer telemetry:emit '{"ts":"2026-04-03T10:00:00Z","tool":"queue","cmd":"list","items":8}'
}

# --- JSON output ---

@test "list --json outputs all events as JSONL" {
  run shimmer telemetry:list -- --json --limit 0
  [ "$status" -eq 0 ]
  LINES=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINES" -eq 5 ]
}

@test "list --json outputs valid JSON per line" {
  run shimmer telemetry:list -- --json --limit 0
  [ "$status" -eq 0 ]
  echo "$output" | while read -r line; do
    echo "$line" | jq empty
  done
}

# --- Filtering ---

@test "list --tool filters by tool name" {
  run shimmer telemetry:list -- --json --tool queue --limit 0
  [ "$status" -eq 0 ]
  LINES=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINES" -eq 3 ]
  # All lines should be queue
  echo "$output" | jq -e '.tool == "queue"'
}

@test "list --cmd filters by command name" {
  run shimmer telemetry:list -- --json --cmd list --limit 0
  [ "$status" -eq 0 ]
  LINES=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINES" -eq 3 ]
}

@test "list --since filters by date" {
  run shimmer telemetry:list -- --json --since "2026-04-02" --limit 0
  [ "$status" -eq 0 ]
  LINES=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINES" -eq 3 ]
}

@test "list --tool and --cmd compose" {
  run shimmer telemetry:list -- --json --tool queue --cmd list --limit 0
  [ "$status" -eq 0 ]
  LINES=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINES" -eq 2 ]
}

# --- Limit ---

@test "list --limit restricts output" {
  run shimmer telemetry:list -- --json --limit 2
  [ "$status" -eq 0 ]
  LINES=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINES" -eq 2 ]
}

@test "list default limit is 20" {
  # We only have 5 events, so default limit shows all
  run shimmer telemetry:list -- --json
  [ "$status" -eq 0 ]
  LINES=$(echo "$output" | wc -l | tr -d ' ')
  [ "$LINES" -eq 5 ]
}

# --- Table output ---

@test "list renders a table by default" {
  run shimmer telemetry:list
  [ "$status" -eq 0 ]
  # Table has borders
  echo "$output" | grep -q "│"
  # Shows tool names
  echo "$output" | grep -q "queue"
  echo "$output" | grep -q "chat"
}

# --- Edge cases ---

@test "list with no matching filter shows message" {
  run shimmer telemetry:list -- --tool nonexistent
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "No matching events"
}

@test "list fails when TELEMETRY_FILE not set" {
  unset TELEMETRY_FILE
  run shimmer telemetry:list
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "TELEMETRY_FILE not set"
}
