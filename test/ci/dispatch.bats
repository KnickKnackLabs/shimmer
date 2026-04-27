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

@test "dispatch: preserves spaces in input values" {
  mock_gh 12345
  mock_shimmer

  run shimmer ci:dispatch test.yml "message=hello world from CI" model=opus --repo test/repo
  [ "$status" -eq 0 ]

  # The full value including spaces should appear as a single -f arg
  grep "workflow run" "$GH_LOG" | grep -q "message=hello world from CI"
}

@test "dispatch: preserves embedded newlines in input values" {
  mock_gh 12345
  mock_shimmer

  message=$'line1\nline2'
  run shimmer ci:dispatch test.yml "message=$message" model=opus --repo test/repo
  [ "$status" -eq 0 ]

  log=$(cat "$GH_LOG")
  [[ "$log" == *$'message=line1\nline2'* ]]
  [[ "$log" == *"model=opus"* ]]
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

@test "dispatch: polls immediately when run is already indexed" {
  mock_gh 99999
  mock_shimmer

  run shimmer ci:dispatch test.yml --repo test/repo --timeout 30
  [ "$status" -eq 0 ]
  [[ "$output" == *"99999"* ]]

  POLL_COUNT=$(cat "$GH_POLL_COUNT")
  [ "$POLL_COUNT" -eq 1 ]
  [ ! -s "$SLEEP_LOG" ]
}

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

  run shimmer ci:dispatch test.yml --repo test/repo --timeout 0
  [ "$status" -eq 1 ]
  [[ "$output" == *"no matching run appeared within 0s"* ]]
}

@test "dispatch: timeout error includes workflow URL" {
  mock_gh_no_runs
  mock_shimmer

  run shimmer ci:dispatch test.yml --repo owner/repo --timeout 0
  [ "$status" -eq 1 ]
  [[ "$output" == *"owner/repo/actions/workflows/test.yml"* ]]
  [[ "$output" == *"gh run list --repo 'owner/repo' --workflow 'test.yml' --limit 5"* ]]
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
