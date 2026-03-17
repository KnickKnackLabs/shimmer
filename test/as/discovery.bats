#!/usr/bin/env bats

setup() {
  load helpers
}

teardown() {
  rm -rf "$TEST_HOME" "$OVERLAY" "$BATS_TEST_TMPDIR/mocks-$$"
}

# ============ Agent discovery (no mocks needed) ============

@test "discovery: lists agents from home's agent:list task" {
  setup_test_home "alice" "bob"
  run mise -C "$TEST_HOME" run -q agent:list
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx "alice"
  echo "$output" | grep -qx "bob"
}

@test "discovery: agent:identity returns content, not path" {
  setup_test_home "alice"
  run mise -C "$TEST_HOME" run -q agent:identity alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"You are alice."* ]]
}

# ============ Full as flow (secret:get mocked) ============

@test "as: outputs export statements for valid agent" {
  setup_test_home "alice" "bob"
  mock_task "secret/get" 'echo "ghp_fake_test_token"'
  mock_shimmer

  run run_as alice
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export GIT_AUTHOR_NAME='alice'"
  echo "$output" | grep -q "export GIT_AUTHOR_EMAIL='alice@ricon.family'"
  echo "$output" | grep -q "export GH_TOKEN='ghp_fake_test_token'"
}

@test "as: sets AGENT_HOME to the home directory" {
  setup_test_home "alice"
  mock_task "secret/get" 'echo "ghp_fake"'
  mock_shimmer

  run run_as alice
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export AGENT_HOME="
  echo "$output" | grep -q "$(basename "$TEST_HOME")"
}

@test "as: AGENT_IDENTITY contains identity content" {
  setup_test_home "alice"
  mock_task "secret/get" 'echo "ghp_fake"'
  mock_shimmer

  run run_as alice
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export AGENT_IDENTITY="
  echo "$output" | grep -q "You are alice."
}

@test "as: works for each agent independently" {
  setup_test_home "alice" "bob"
  mock_task "secret/get" 'echo "ghp_fake"'
  mock_shimmer

  run run_as bob
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export GIT_AUTHOR_NAME='bob'"
}

# ============ Validation (no mocks — fails before secrets) ============

@test "as: rejects unknown agent" {
  setup_test_home "alice" "bob"
  mock_shimmer

  run run_as charlie
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown agent: charlie"* ]]
}

@test "as: shows available agents on rejection" {
  setup_test_home "alice" "bob"
  mock_shimmer

  run run_as charlie
  [[ "$output" == *"alice"* ]]
  [[ "$output" == *"bob"* ]]
}

# ============ Missing agent:list (no mocks, no overlay) ============

@test "as: fails gracefully when home has no agent:list" {
  # Bare home — no tasks at all
  TEST_HOME="$BATS_TEST_TMPDIR/bare-$$"
  mkdir -p "$TEST_HOME"
  git -C "$TEST_HOME" init -q -b main
  git -C "$TEST_HOME" config user.email "test@test.com"
  git -C "$TEST_HOME" config user.name "Test"

  run env CALLER_PWD="$TEST_HOME" mise -C "$SHIMMER_DIR" run -q as alice 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not list agents"* ]]
}
