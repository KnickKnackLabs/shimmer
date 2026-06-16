#!/usr/bin/env bats

setup() {
  load helpers
}

teardown() {
  rm -rf "$TEST_HOME" "$OVERLAY" "$TEST_AGENTS_ROOT" "$BATS_TEST_TMPDIR/mocks-$$" "$BATS_TEST_TMPDIR/mock-bin-$$"
}

# ============ Agent discovery (no mocks needed) ============

@test "discovery: lists agents from home's agent:list task" {
  setup_test_home "alice" "bob"
  run mise -C "$TEST_HOME" run -q agent:list
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx "alice"
  echo "$output" | grep -qx "bob"
}

# ============ Full as flow (secrets binary mocked) ============

@test "as: test helper clears ambient Git config overrides" {
  [ -z "${GIT_CONFIG_COUNT:-}" ]
  [ -z "${GIT_CONFIG_KEY_0:-}" ]
  [ -z "${GIT_CONFIG_VALUE_0:-}" ]
}

@test "as: outputs export statements for valid agent" {
  setup_test_home "alice" "bob"
  mock_secrets_binary "alice/github-pat=ghp_fake_test_token"
  mock_shimmer

  run shimmer as alice
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "export GIT_AUTHOR_NAME='alice'"
  echo "$output" | grep -q "export GIT_AUTHOR_EMAIL='alice@ricon.family'"
  echo "$output" | grep -q "export GH_TOKEN='ghp_fake_test_token'"
  echo "$output" | grep -q "export GIT_CONFIG_KEY_0='user.name'"
  echo "$output" | grep -q "export GIT_CONFIG_VALUE_0='alice'"
  echo "$output" | grep -q "export GIT_CONFIG_KEY_2='user.signingkey'"
  echo "$output" | grep -q "export GIT_CONFIG_VALUE_2='TESTKEY-alice'"
  echo "$output" | grep -q "export GIT_CONFIG_KEY_3='commit.gpgsign'"
  echo "$output" | grep -q "export GIT_CONFIG_KEY_4='tag.gpgsign'"
  echo "$output" | grep -q "export GIT_CONFIG_COUNT='5'"
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

@test "as: does not export prompt text" {
  setup_test_home "alice"
  mock_secrets_binary
  mock_shimmer

  run shimmer as alice
  [ "$status" -eq 0 ]
  [[ "$output" != *"You are alice."* ]]
}

@test "as: falls back to private home when caller repo has no agent:list" {
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake"
  mock_shimmer

  local caller="$BATS_TEST_TMPDIR/plain-repo"
  mkdir -p "$caller"
  git -C "$caller" init -q -b main

  run env SHIMMER_CALLER_PWD="$caller" mise -C "$OVERLAY" run -q as alice 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not provide agent:list; using"* ]]
  echo "$output" | grep -q "export AGENT_HOME='$TEST_AGENTS_ROOT/alice/home'"
  echo "$output" | grep -q "export GIT_CONFIG_VALUE_2='TESTKEY-alice'"
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

@test "as: eval preserves apostrophes in exported values" {
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake'quoted" "alice/b2-bucket=bucket'quoted"
  mock_shimmer

  eval "$(shimmer as alice 2>/dev/null)"

  [ "$GH_TOKEN" = "ghp_fake'quoted" ]
  [ "$B2_BUCKET" = "bucket'quoted" ]
}

@test "as: unquoted eval preserves apostrophes in exported values" {
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake'quoted" "alice/b2-bucket=bucket'quoted"
  mock_shimmer

  local script="$BATS_TEST_TMPDIR/unquoted-eval-apostrophe.sh"
  cat > "$script" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

home="$1"
overlay="$2"

eval $(SHIMMER_CALLER_PWD="$home" mise -C "$overlay" run -q as alice 2>/dev/null)

printf 'token=%s\n' "$GH_TOKEN"
printf 'bucket=%s\n' "$B2_BUCKET"
SCRIPT
  chmod +x "$script"

  run "$script" "$TEST_HOME" "$OVERLAY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"token=ghp_fake'quoted"* ]]
  [[ "$output" == *"bucket=bucket'quoted"* ]]
}

@test "as: eval makes Git config use active agent signing identity in other repos" {
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake"
  mock_shimmer

  local repo="$BATS_TEST_TMPDIR/work-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.name "Wrong Name"
  git -C "$repo" config user.email "wrong@example.invalid"
  git -C "$repo" config user.signingkey "WRONGKEY"
  git -C "$repo" config commit.gpgsign false

  eval "$(shimmer as alice 2>/dev/null)"

  [ "$(git -C "$repo" config user.name)" = "alice" ]
  [ "$(git -C "$repo" config user.email)" = "alice@ricon.family" ]
  [ "$(git -C "$repo" config user.signingkey)" = "TESTKEY-alice" ]
  [ "$(git -C "$repo" config commit.gpgsign)" = "true" ]
  [ "$(git -C "$repo" config tag.gpgsign)" = "true" ]
}

@test "as: appends Git config overrides without dropping existing entries" {
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake"
  mock_shimmer

  local repo="$BATS_TEST_TMPDIR/work-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q -b main

  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0="core.editor"
  export GIT_CONFIG_VALUE_0="vim"

  eval "$(shimmer as alice 2>/dev/null)"

  [ "$GIT_CONFIG_COUNT" = "6" ]
  [ "$GIT_CONFIG_KEY_0" = "core.editor" ]
  [ "$GIT_CONFIG_VALUE_0" = "vim" ]
  [ "$(git -C "$repo" config core.editor)" = "vim" ]
  [ "$(git -C "$repo" config user.signingkey)" = "TESTKEY-alice" ]

  unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
}

@test "as: switching agents makes later Git config overrides win" {
  setup_test_home "alice" "bob"
  mock_secrets_binary "alice/github-pat=ghp_alice" "bob/github-pat=ghp_bob"
  mock_shimmer

  local repo="$BATS_TEST_TMPDIR/work-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q -b main

  eval "$(shimmer as alice 2>/dev/null)"
  eval "$(shimmer as bob 2>/dev/null)"

  [ "$(git -C "$repo" config user.name)" = "bob" ]
  [ "$(git -C "$repo" config user.email)" = "bob@ricon.family" ]
  [ "$(git -C "$repo" config user.signingkey)" = "TESTKEY-bob" ]
}

@test "as: disables signing overrides when agent signing key is missing" {
  setup_test_home "alice"
  rm -rf "$TEST_AGENTS_ROOT/alice"
  mock_secrets_binary "alice/github-pat=ghp_fake"
  mock_shimmer

  run shimmer as alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning: no signing key found for alice"* ]]
  echo "$output" | grep -q "export GIT_CONFIG_KEY_0='user.name'"
  echo "$output" | grep -q "export GIT_CONFIG_KEY_2='user.signingkey'"
  echo "$output" | grep -q "export GIT_CONFIG_VALUE_2=''"
  echo "$output" | grep -q "export GIT_CONFIG_KEY_3='commit.gpgsign'"
  echo "$output" | grep -q "export GIT_CONFIG_VALUE_3='false'"
  echo "$output" | grep -q "export GIT_CONFIG_KEY_4='tag.gpgsign'"
  echo "$output" | grep -q "export GIT_CONFIG_VALUE_4='false'"
  echo "$output" | grep -q "export GIT_CONFIG_COUNT='5'"
}

@test "as: missing signing key does not reuse previous agent signing overrides" {
  setup_test_home "alice" "bob"
  rm -rf "$TEST_AGENTS_ROOT/bob"
  mock_secrets_binary "alice/github-pat=ghp_alice" "bob/github-pat=ghp_bob"
  mock_shimmer

  local repo="$BATS_TEST_TMPDIR/work-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q -b main

  eval "$(shimmer as alice 2>/dev/null)"
  eval "$(shimmer as bob 2>/dev/null)"

  [ "$(git -C "$repo" config user.name)" = "bob" ]
  [ "$(git -C "$repo" config user.signingkey)" = "" ]
  [ "$(git -C "$repo" config commit.gpgsign)" = "false" ]
  [ "$(git -C "$repo" config tag.gpgsign)" = "false" ]
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
  if echo "$output" | grep -q "export B2_BUCKET="; then
    echo "unexpected B2_BUCKET export" >&2
    return 1
  fi
}

@test "as: bridges SHIMMER_SECRETS_PROVIDER to SECRETS_PROVIDER" {
  setup_test_home "alice"
  mock_secrets_binary
  mock_shimmer

  # Set old env var, verify task still works (bridge picks it up)
  run env SHIMMER_SECRETS_PROVIDER=keychain SHIMMER_CALLER_PWD="$TEST_HOME" mise -C "$OVERLAY" run -q as alice 2>&1
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
    case "$var" in
      GIT_CONFIG_*) continue ;;
    esac
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

  local script="$BATS_TEST_TMPDIR/unquoted-eval-bash.sh"
  cat > "$script" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

home="$1"
overlay="$2"

# Intentionally unquoted: this preserves compatibility with the historical
# documented form, `eval $(shimmer as <agent>)`.
eval $(SHIMMER_CALLER_PWD="$home" mise -C "$overlay" run -q as alice 2>/dev/null)

printf 'name=%s\n' "$GIT_AUTHOR_NAME"
printf 'host=%s\n' "$GH_HOST"
SCRIPT
  chmod +x "$script"

  run "$script" "$TEST_HOME" "$OVERLAY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"name=alice"* ]]
  [[ "$output" == *"host=github.com"* ]]
}

@test "as: unquoted eval works in zsh" {
  command -v zsh >/dev/null 2>&1 || skip "zsh not installed"
  setup_test_home "alice"
  mock_secrets_binary "alice/github-pat=ghp_fake"
  mock_shimmer

  local script="$BATS_TEST_TMPDIR/unquoted-eval-zsh.zsh"
  cat > "$script" <<'SCRIPT'
set -euo pipefail

home="$1"
overlay="$2"

# Intentionally unquoted: this preserves compatibility with the historical
# documented form, `eval $(shimmer as <agent>)`.
eval $(SHIMMER_CALLER_PWD="$home" mise -C "$overlay" run -q as alice 2>/dev/null)

print -r -- "name=$GIT_AUTHOR_NAME"
print -r -- "host=$GH_HOST"
SCRIPT

  run zsh "$script" "$TEST_HOME" "$OVERLAY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"name=alice"* ]]
  [[ "$output" == *"host=github.com"* ]]
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

@test "as: fails when agent:list fails" {
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

@test "as: rejects agent omitted from list" {
  setup_test_home "alice"
  mock_shimmer

  run shimmer as charlie
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown agent: charlie"* ]]
  [[ "$output" == *"alice"* ]]
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
