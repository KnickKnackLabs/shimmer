#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load helpers.bash

# --- Basic emit ---

@test "emit appends event to TELEMETRY_FILE" {
  run shimmer telemetry:emit '{"tool":"queue","cmd":"list","items":5}'
  [ "$status" -eq 0 ]
  [ -f "$TELEMETRY_FILE" ]
  [ "$(wc -l < "$TELEMETRY_FILE" | tr -d ' ')" -eq 1 ]
  jq -e '.tool == "queue"' "$TELEMETRY_FILE"
}

@test "emit auto-populates ts when missing" {
  run shimmer telemetry:emit '{"tool":"chat","cmd":"read"}'
  [ "$status" -eq 0 ]
  jq -e '.ts' "$TELEMETRY_FILE"
}

@test "emit preserves ts when provided" {
  run shimmer telemetry:emit '{"tool":"chat","cmd":"read","ts":"2026-01-01T00:00:00Z"}'
  [ "$status" -eq 0 ]
  jq -e '.ts == "2026-01-01T00:00:00Z"' "$TELEMETRY_FILE"
}

@test "emit orders fields: ts, tool, cmd first" {
  run shimmer telemetry:emit '{"items":5,"cmd":"list","tool":"queue"}'
  [ "$status" -eq 0 ]
  # First three keys should be ts, tool, cmd
  KEYS=$(jq -r 'keys_unsorted[:3] | join(",")' "$TELEMETRY_FILE")
  [ "$KEYS" = "ts,tool,cmd" ]
}

@test "emit appends multiple events" {
  shimmer telemetry:emit '{"tool":"queue","cmd":"list"}'
  shimmer telemetry:emit '{"tool":"chat","cmd":"read"}'
  shimmer telemetry:emit '{"tool":"threads","cmd":"list"}'
  [ "$(wc -l < "$TELEMETRY_FILE" | tr -d ' ')" -eq 3 ]
}

# --- No-op when off ---

@test "emit is a no-op when TELEMETRY_FILE is unset" {
  unset TELEMETRY_FILE
  run shimmer telemetry:emit '{"tool":"queue","cmd":"list"}'
  [ "$status" -eq 0 ]
}

# --- Validation ---

@test "emit rejects invalid JSON" {
  run shimmer telemetry:emit 'not json'
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid JSON"* ]]
}

@test "emit rejects event missing tool field" {
  run shimmer telemetry:emit '{"cmd":"list"}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"tool"* ]]
}

@test "emit rejects event missing cmd field" {
  run shimmer telemetry:emit '{"tool":"queue"}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"cmd"* ]]
}

# --- Hook pipeline ---

@test "emit pipes event through TELEMETRY_HOOK" {
  # Hook that adds an "agent" field
  HOOK="$BATS_TEST_TMPDIR/hook-$$.sh"
  cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
jq -c '. + {"agent":"zeke"}'
EOF
  chmod +x "$HOOK"
  export TELEMETRY_HOOK="$HOOK"

  run shimmer telemetry:emit '{"tool":"queue","cmd":"list"}'
  [ "$status" -eq 0 ]
  jq -e '.agent == "zeke"' "$TELEMETRY_FILE"
}

@test "emit drops event when hook returns nothing" {
  # Hook that filters everything
  HOOK="$BATS_TEST_TMPDIR/hook-$$.sh"
  cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
# Drop all events — output nothing
EOF
  chmod +x "$HOOK"
  export TELEMETRY_HOOK="$HOOK"

  run shimmer telemetry:emit '{"tool":"queue","cmd":"list"}'
  [ "$status" -eq 0 ]
  # File should not exist (no events written)
  [ ! -f "$TELEMETRY_FILE" ]
}

@test "emit fails when TELEMETRY_HOOK is not executable" {
  HOOK="$BATS_TEST_TMPDIR/hook-$$.sh"
  echo "#!/usr/bin/env bash" > "$HOOK"
  # deliberately NOT chmod +x
  export TELEMETRY_HOOK="$HOOK"

  run shimmer telemetry:emit '{"tool":"queue","cmd":"list"}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"not executable"* ]]
}

# --- Creates parent directory ---

@test "emit creates parent directories for TELEMETRY_FILE" {
  export TELEMETRY_FILE="$BATS_TEST_TMPDIR/deep/nested/dir/telemetry-$$.jsonl"
  run shimmer telemetry:emit '{"tool":"queue","cmd":"list"}'
  [ "$status" -eq 0 ]
  [ -f "$TELEMETRY_FILE" ]
}
