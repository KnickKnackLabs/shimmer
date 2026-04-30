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

# ============ Stale environment clearing ============

@test "as: clears previous identity vars before setting new ones" {
  setup_test_home "alice" "bob"
  mock_secrets_binary
  mock_shimmer

  # Capture the output and check that unset comes before export
  run shimmer as alice
  [ "$status" -eq 0 ]

  # Every exported var should be unset first
  local var
  for var in $(echo "$output" | grep -oE "export [A-Z_]+" | awk '{print $2}' | sort -u); do
    echo "$output" | grep -q "unset.*$var" || {
      echo "exported var $var is not unset" >&2
      return 1
    }
  done

  # unset should come before the first export
  local first_unset first_export
  first_unset=$(echo "$output" | grep -n "unset" | head -1 | cut -d: -f1)
  first_export=$(echo "$output" | grep -n "export" | head -1 | cut -d: -f1)
  [ "$first_unset" -lt "$first_export" ]
}

@test "as: eval clears stale AGENT_IDENTITY from previous session" {
  setup_test_home "alice" "bob"
  mock_secrets_binary
  mock_shimmer

  # Simulate: previous session set AGENT_IDENTITY to bob
  export AGENT_IDENTITY="You are bob."

  # Switch to alice via eval
  eval "$(shimmer as alice 2>/dev/null)"

  # Should be alice's identity, not bob's
  [[ "$AGENT_IDENTITY" == *"You are alice."* ]]
  [[ "$AGENT_IDENTITY" != *"You are bob."* ]]
}

@test "as: eval clears stale B2_BUCKET when new agent has none" {
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake"
  mock_shimmer

  # Simulate: previous session set B2_BUCKET
  export B2_BUCKET="old-bucket"

  eval "$(shimmer as alice 2>/dev/null)"

  # B2_BUCKET should be cleared since alice has no bucket configured
  [ -z "${B2_BUCKET:-}" ]
}

@test "as: unquoted eval works in bash" {
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake"
  mock_shimmer

  run bash -c 'eval $(CALLER_PWD="$1" mise -C "$2" run -q as alice 2>/dev/null); printf "%s|%s|%s\n" "$GIT_AUTHOR_NAME" "$GH_HOST" "$AGENT_IDENTITY"' _ "$TEST_HOME" "$OVERLAY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice|github.com|"* ]]
  [[ "$output" == *"You are alice."* ]]
}

@test "as: unquoted eval works in zsh" {
  command -v zsh >/dev/null 2>&1 || skip "zsh not installed"
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake"
  mock_shimmer

  run zsh -fc 'eval $(CALLER_PWD="$1" mise -C "$2" run -q as alice 2>/dev/null); print -r -- "$GIT_AUTHOR_NAME|$GH_HOST|$AGENT_IDENTITY"' _ "$TEST_HOME" "$OVERLAY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice|github.com|"* ]]
  [[ "$output" == *"You are alice."* ]]
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

@test "as: fails when agent:list fails even if identity resolves" {
  setup_test_home "alice"
  cat > "$TEST_HOME/.mise/tasks/agent/list" <<'TASK'
#!/usr/bin/env bash
#MISE description="List agents"
echo "agent:list unavailable" >&2
exit 1
TASK
  chmod +x "$TEST_HOME/.mise/tasks/agent/list"
  mock_secrets_binary "alice/github-pat=ghp_fake_test_token"
  mock_shimmer

  run shimmer as alice
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not list agents"* ]]
  [[ "$output" == *"agent:list stderr:"* ]]
  [[ "$output" == *"agent:list unavailable"* ]]
  [[ "$output" != *"export GIT_AUTHOR_NAME='alice'"* ]]
  [[ "$output" != *"You are alice."* ]]
}

@test "as: rejects agent omitted from list even if identity file exists" {
  setup_test_home "alice"
  cat > "$TEST_HOME/notes/charlie.md" <<'EOF'
---
title: charlie
tags: [agent, identity]
---

# charlie
You are charlie.
EOF
  mock_shimmer

  run shimmer as charlie
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown agent: charlie"* ]]
  [[ "$output" == *"alice"* ]]
  [[ "$output" != *"You are charlie."* ]]
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
