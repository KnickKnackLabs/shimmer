#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load helpers.bash

setup() {
  export TELEMETRY_FILE="$BATS_TEST_TMPDIR/telemetry-$$.jsonl"
  unset TELEMETRY_HOOK
  mock_shimmer
}

@test "status shows file path when configured" {
  run shimmer telemetry:status
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "TELEMETRY_FILE"
  echo "$output" | grep -q "$TELEMETRY_FILE"
}

@test "status shows telemetry is off when TELEMETRY_FILE unset" {
  unset TELEMETRY_FILE
  run shimmer telemetry:status
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "not set"
}

@test "status shows no events when file doesn't exist" {
  run shimmer telemetry:status
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "No events yet"
}

@test "status shows event count" {
  shimmer telemetry:emit '{"tool":"queue","cmd":"list"}'
  shimmer telemetry:emit '{"tool":"chat","cmd":"read"}'
  shimmer telemetry:emit '{"tool":"queue","cmd":"peek"}'

  run shimmer telemetry:status
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Events.*3"
}

@test "status shows tool breakdown" {
  shimmer telemetry:emit '{"tool":"queue","cmd":"list"}'
  shimmer telemetry:emit '{"tool":"queue","cmd":"peek"}'
  shimmer telemetry:emit '{"tool":"chat","cmd":"read"}'

  run shimmer telemetry:status
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "queue.*2"
  echo "$output" | grep -q "chat.*1"
}

@test "status shows hook path when configured" {
  HOOK="$BATS_TEST_TMPDIR/hook-$$.sh"
  echo '#!/usr/bin/env bash' > "$HOOK"
  chmod +x "$HOOK"
  export TELEMETRY_HOOK="$HOOK"

  run shimmer telemetry:status
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "TELEMETRY_HOOK"
  echo "$output" | grep -q "$HOOK"
}
