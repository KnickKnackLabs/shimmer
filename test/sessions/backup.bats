#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load helpers
}

# --- Session backup ---

@test "sessions:backup --all exports all listed sessions in dry-run mode" {
  mock_sessions_backup_tools '[{"session_id":"session-001"},{"session_id":"session-002"}]'
  mock_shimmer

  run shimmer sessions:backup --all --dry-run
  [ "$status" -eq 0 ]

  grep -q '^list --all --json --limit 10000$' "$SESSIONS_LOG"
  grep -q '^export --output .* --format bundle session-001$' "$SESSIONS_LOG"
  grep -q '^export --output .* --format bundle session-002$' "$SESSIONS_LOG"
  [[ "$output" == *"snapshot_key=sessions/session-001/snapshots/"* ]]
  [[ "$output" == *"snapshot_key=sessions/session-002/snapshots/"* ]]
  [ ! -f "$BLOBS_LOG" ]
}

@test "sessions:backup uploads explicit sessions with agent credentials" {
  mock_sessions_backup_tools '[]'
  export AGENT="test-agent"
  mock_shimmer

  run shimmer sessions:backup session-001 session-002
  [ "$status" -eq 0 ]

  ! grep -q '^list ' "$SESSIONS_LOG"
  grep -q '^export --output .* --format bundle session-001$' "$SESSIONS_LOG"
  grep -q '^export --output .* --format bundle session-002$' "$SESSIONS_LOG"
  grep -q '^setup$' "$BLOBS_LOG"
  grep -q '^put sessions/session-001/snapshots/.*\.tar\.gz .*$' "$BLOBS_LOG"
  grep -q '^put sessions/session-001/latest\.tar\.gz .*$' "$BLOBS_LOG"
  grep -q '^put sessions/session-002/snapshots/.*\.tar\.gz .*$' "$BLOBS_LOG"
  grep -q '^put sessions/session-002/latest\.tar\.gz .*$' "$BLOBS_LOG"
}

@test "sessions:backup skips before session inspection when credentials are absent" {
  mock_sessions_backup_tools '__FAIL__'
  export AGENT="missing-agent"
  mock_shimmer

  run shimmer sessions:backup --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"B2 credentials not configured; skipping session backup"* ]]
  [ ! -f "$SESSIONS_LOG" ]
  [ ! -f "$BLOBS_LOG" ]
}


@test "sessions:backup --all skips when sessions dir is missing" {
  mock_sessions_backup_tools '__NO_SESSIONS_DIR__'
  export AGENT="test-agent"
  mock_shimmer

  run shimmer sessions:backup --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"no sessions directory"* ]]
  [[ "$output" == *"no sessions found; skipping"* ]]
  grep -q '^list --all --json --limit 10000$' "$SESSIONS_LOG"
  [ ! -f "$BLOBS_LOG" ]
}

@test "sessions:backup fails when configured backup cannot list sessions" {
  mock_sessions_backup_tools '__FAIL__'
  export AGENT="test-agent"
  mock_shimmer

  run shimmer sessions:backup --all
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not list sessions"* ]]
  [[ "$output" == *"mock list failure"* ]]
  grep -q '^list --all --json --limit 10000$' "$SESSIONS_LOG"
  [ ! -f "$BLOBS_LOG" ]
}

@test "sessions:backup requires explicit sessions or --all" {
  mock_sessions_backup_tools '[]'
  mock_shimmer

  run shimmer sessions:backup
  [ "$status" -ne 0 ]
  [[ "$output" == *"provide session IDs or pass --all"* ]]
}
