# Shared test helpers for shimmer BATS tests
#
# Uses the "mock-first include overlay" pattern: a tiny mise project
# whose task_config includes mock tasks before shimmer's real tasks.
# First include wins, so mocks override without copying anything.
# The overlay also declares tool versions needed by unmocked tasks.
#
# Usage: source this from suite-specific helpers.bash files.

# Project root — derived from this file's location so tests work whether
# invoked via `mise run test` or directly with `bats test/...`. We can't
# rely on $MISE_CONFIG_ROOT: it's unset when bats is invoked directly,
# and even under `mise run test` it points at the nearest mise.toml,
# which may be an overlay rather than the real shimmer root. The
# codebase tool's lint:mcr-scope rule enforces this pattern.
SHIMMER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Agent sessions inject command-scope git config via GIT_CONFIG_* so real
# workspace commits use the active agent identity/signing key. Tests should not
# inherit that ambient launch context: suites that exercise `shimmer as` need to
# start from a predictable empty command-scope config, and can still set their
# own GIT_CONFIG_* values inside individual tests.
_clear_ambient_git_config_for_tests() {
  local name _value
  unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
  while IFS='=' read -r name _value; do
    case "$name" in
      GIT_CONFIG_KEY_*|GIT_CONFIG_VALUE_*) unset "$name" ;;
    esac
  done < <(env)
}
_clear_ambient_git_config_for_tests

# Create a mock task file. Call this before mock_shimmer.
# Usage: mock_task "email/quota" 'echo "Usage: 50%"'
mock_task() {
  local task_path="$1" body="$2"
  local mock_dir="$BATS_TEST_TMPDIR/mocks-$$"
  mkdir -p "$mock_dir/$(dirname "$task_path")"
  cat > "$mock_dir/$task_path" <<EOF
#!/usr/bin/env bash
$body
EOF
  chmod +x "$mock_dir/$task_path"
}

# Build an overlay that includes: test home tasks (if any), mocks (if any), then shimmer.
# Must be called after setup_test_home (if used) and any mock_task calls.
# Usage: mock_shimmer
mock_shimmer() {
  local mock_dir="$BATS_TEST_TMPDIR/mocks-$$"
  OVERLAY="$BATS_TEST_TMPDIR/overlay-$$"
  mkdir -p "$OVERLAY"
  ln -s "$SHIMMER_DIR/lib" "$OVERLAY/lib"

  # Build includes list: home tasks first (if any), then mocks (if any), then shimmer
  local includes=""
  if [ -n "${TEST_HOME:-}" ] && [ -d "$TEST_HOME/.mise/tasks" ]; then
    includes="\"$TEST_HOME/.mise/tasks\""
  fi
  if [ -d "$mock_dir" ]; then
    [ -n "$includes" ] && includes="$includes, "
    includes="${includes}\"$mock_dir\""
  fi
  [ -n "$includes" ] && includes="$includes, "
  includes="${includes}\"$SHIMMER_DIR/.mise/tasks\""

  cat > "$OVERLAY/mise.toml" <<EOF
[tools]
gum = "0.17.0"

[task_config]
includes = [$includes]
EOF
  git -C "$OVERLAY" init -q -b main
  git -C "$OVERLAY" config user.email "test@test.com"
  git -C "$OVERLAY" config user.name "Test"
  mise trust "$OVERLAY/mise.toml" 2>/dev/null

  export OVERLAY
}

# Create a mock `secrets` binary on PATH.
# Returns canned values based on the key argument.
# Usage: mock_secrets_binary ["key1=value1" "key2=value2" ...]
# With no args, returns "mock-token" for any get call.
mock_secrets_binary() {
  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin-$$"
  mkdir -p "$MOCK_BIN"

  # Build case branches from args
  local case_body=""
  for entry in "$@"; do
    local key="${entry%%=*}"
    local value="${entry#*=}"
    case_body+="      \"$key\") echo \"$value\" ;;"$'\n'
  done

  if [ -z "$case_body" ]; then
    # Default: return mock-token for any get, succeed silently for set
    cat > "$MOCK_BIN/secrets" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  get) echo "mock-token" ;;
  set) ;; # silent success
  *) echo "mock secrets: unknown command $1" >&2; exit 1 ;;
esac
MOCK
  else
    cat > "$MOCK_BIN/secrets" <<MOCK
#!/usr/bin/env bash
case "\$1" in
  get)
    case "\$2" in
$case_body      *) echo "ERROR: No secret found for key=\$2" >&2; exit 1 ;;
    esac
    ;;
  set) ;; # silent success
  *) echo "mock secrets: unknown command \$1" >&2; exit 1 ;;
esac
MOCK
  fi
  chmod +x "$MOCK_BIN/secrets"

  export PATH="$MOCK_BIN:$PATH"
}

# Call shimmer tasks through mise, matching real usage.
# Usage: shimmer welcome
# Usage: shimmer as alice
shimmer() {
  local caller="${SHIMMER_CALLER_PWD:-${TEST_HOME:-.}}"
  SHIMMER_CALLER_PWD="$caller" mise -C "$OVERLAY" run -q "$@" 2>&1
}
export -f shimmer
