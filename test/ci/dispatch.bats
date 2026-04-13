#!/usr/bin/env bats
# ci:dispatch tests — workflow triggering and run ID polling

bats_require_minimum_version 1.5.0

setup() {
  load helpers
}

# ============================================================================
# Happy path
# ============================================================================

@test "dispatch: triggers workflow and returns run ID" {
  mock_gh 12345
  mock_shimmer

  run shimmer ci:dispatch test.yml --repo test/repo
  [ "$status" -eq 0 ]
  [[ "$output" == *"12345"* ]]
}

@test "dispatch: calls gh workflow run with correct args" {
  mock_gh 12345
  mock_shimmer

  run shimmer ci:dispatch deploy.yml --repo owner/repo
  [ "$status" -eq 0 ]

  grep -q "workflow run deploy.yml -R owner/repo" "$GH_LOG"
}

@test "dispatch: passes input flags to gh workflow run" {
  mock_gh 12345
  mock_shimmer

  run shimmer ci:dispatch test.yml message=hello model=opus --repo test/repo
  [ "$status" -eq 0 ]

  grep "workflow run" "$GH_LOG" | grep -q "message=hello"
  grep "workflow run" "$GH_LOG" | grep -q "model=opus"
}

@test "dispatch: shows human-friendly info on stderr" {
  mock_gh 12345
  mock_shimmer

  run shimmer ci:dispatch test.yml --repo test/repo
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dispatched test.yml"* ]]
  [[ "$output" == *"run 12345"* ]]
}

# ============================================================================
# Polling behavior
# ============================================================================

@test "dispatch: polls until run appears" {
  mock_gh 99999 2  # run appears after 2 polls
  mock_shimmer

  run shimmer ci:dispatch test.yml --repo test/repo --timeout 30
  [ "$status" -eq 0 ]
  [[ "$output" == *"99999"* ]]

  # Should have polled more than once
  POLL_COUNT=$(cat "$GH_POLL_COUNT")
  [ "$POLL_COUNT" -ge 2 ]
}

# ============================================================================
# Timeout
# ============================================================================

@test "dispatch: times out when run never appears" {
  mock_gh_no_runs
  mock_shimmer

  run shimmer ci:dispatch test.yml --repo test/repo --timeout 3
  [ "$status" -eq 1 ]
  [[ "$output" == *"timed out"* ]]
}

@test "dispatch: timeout error includes workflow URL" {
  mock_gh_no_runs
  mock_shimmer

  run shimmer ci:dispatch test.yml --repo owner/repo --timeout 3
  [ "$status" -eq 1 ]
  [[ "$output" == *"owner/repo/actions/workflows/test.yml"* ]]
}

# ============================================================================
# Actor filtering
# ============================================================================

@test "dispatch: filters runs by actor" {
  mock_gh 12345
  mock_shimmer

  run shimmer ci:dispatch test.yml --repo test/repo
  [ "$status" -eq 0 ]

  # Should have called gh api user to get the actor
  grep -q "api user" "$GH_LOG"
  # Should have passed --user to gh run list
  grep "run list" "$GH_LOG" | grep -q "\-\-user mock-user"
}
