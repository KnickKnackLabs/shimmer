#!/usr/bin/env bats

setup() {
  load helpers
}

teardown() {
  rm -rf "$TEST_HOME" "$OVERLAY" "$BATS_TEST_TMPDIR/mocks-$$" "$BATS_TEST_TMPDIR/mock-bin-$$"
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

# ============ Full as flow (secrets binary mocked) ============

@test "as: outputs export statements for valid agent" {
  setup_test_home "alice" "bob"
  mock_secrets_binary "alice/github-pat=ghp_fake_test_token"
  mock_shimmer

  run shimmer as alice
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export GIT_AUTHOR_NAME='alice'"
  echo "$output" | grep -q "export GIT_AUTHOR_EMAIL='alice@ricon.family'"
  echo "$output" | grep -q "export GH_TOKEN='ghp_fake_test_token'"
}

@test "as: sets AGENT_HOME to the home directory" {
  setup_test_home "alice"
  mock_secrets_binary
  mock_shimmer

  run shimmer as alice
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export AGENT_HOME="
  echo "$output" | grep -q "$(basename "$TEST_HOME")"
}

@test "as: AGENT_IDENTITY contains identity content" {
  setup_test_home "alice"
  mock_secrets_binary
  mock_shimmer

  run shimmer as alice
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export AGENT_IDENTITY="
  echo "$output" | grep -q "You are alice."
}

@test "as: works for each agent independently" {
  setup_test_home "alice" "bob"
  mock_secrets_binary
  mock_shimmer

  run shimmer as bob
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export GIT_AUTHOR_NAME='bob'"
}

@test "as: uses agent-specific PAT from secrets" {
  setup_test_home "alice" "bob"
  mock_secrets_binary "alice/github-pat=ghp_alice_token" "bob/github-pat=ghp_bob_token"
  mock_shimmer

  run shimmer as alice
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export GH_TOKEN='ghp_alice_token'"

  run shimmer as bob
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export GH_TOKEN='ghp_bob_token'"
}

@test "as: exports B2_BUCKET when available" {
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake" "alice/b2-bucket=my-bucket"
  mock_shimmer

  run shimmer as alice
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export B2_BUCKET='my-bucket'"
}

@test "as: succeeds without B2_BUCKET" {
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake"
  mock_shimmer

  run shimmer as alice
  [ "$status" -eq 0 ]
  # Should NOT contain B2_BUCKET export
  ! echo "$output" | grep -q "export B2_BUCKET="
}

@test "as: bridges SHIMMER_SECRETS_PROVIDER to SECRETS_PROVIDER" {
  setup_test_home "alice"
  mock_secrets_binary
  mock_shimmer

  # Set old env var, verify task still works (bridge picks it up)
  run env SHIMMER_SECRETS_PROVIDER=keychain CALLER_PWD="$TEST_HOME" mise -C "$OVERLAY" run -q as alice 2>&1
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export GIT_AUTHOR_NAME='alice'"
}

# ============ Validation (no mocks — fails before secrets) ============

@test "as: rejects unknown agent" {
  setup_test_home "alice" "bob"
  mock_shimmer

  run shimmer as charlie
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown agent: charlie"* ]]
}

@test "as: shows available agents on rejection" {
  setup_test_home "alice" "bob"
  mock_shimmer

  run shimmer as charlie
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
  mock_shimmer

  run shimmer as alice
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not list agents"* ]]
}
