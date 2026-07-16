# Helpers for shimmer agent BATS tests
#
# Uses the mock-first include overlay pattern from test/helpers.bash.
# Mocks the `sessions` binary to test agent task branching without
# launching real session infrastructure.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.bash"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../ci" && pwd)/helpers.bash"

# Set up minimal selected-agent environment.
# Usage: setup_agent [name]
setup_agent() {
  local name="${1:-test-agent}"
  TEST_AGENT_HOME="$BATS_TEST_TMPDIR/${name}-home"
  mkdir -p "$TEST_AGENT_HOME"
  TEST_AGENT_HOME=$(cd "$TEST_AGENT_HOME" && pwd -P)
  git -C "$TEST_AGENT_HOME" init -q -b main

  export TEST_AGENT_HOME
  export AGENT_HOME="$TEST_AGENT_HOME"
  export GIT_AUTHOR_NAME="$name"
  export GIT_AUTHOR_EMAIL="${name}@ricon.family"
  export SHIMMER_CALLER_PWD="$TEST_AGENT_HOME"
}

# Create a mock `sessions` binary on PATH.
# Records calls to a log file for assertion.
# Usage: mock_sessions_binary
mock_sessions_binary() {
  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  SESSIONS_LOG="$BATS_TEST_TMPDIR/sessions-log-$$"
  SESSIONS_ENV_LOG="$BATS_TEST_TMPDIR/sessions-env-log-$$"
  export SESSIONS_LOG SESSIONS_ENV_LOG
  export MOCK_SESSION_ID="${MOCK_SESSION_ID:-mock-resolved-session-id}"
  export MOCK_SESSION_CWD="${MOCK_SESSION_CWD:-${AGENT_HOME:-}}"

  cat > "$MOCK_BIN/sessions" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$SESSIONS_LOG"
{
  printf 'CALLER_PWD=%s\n' "${CALLER_PWD-}"
  printf 'SHIMMER_CALLER_PWD=%s\n' "${SHIMMER_CALLER_PWD-}"
  printf 'OTHER_CALLER_PWD=%s\n' "${OTHER_CALLER_PWD-}"
  printf 'MISE_CONFIG_ROOT=%s\n' "${MISE_CONFIG_ROOT-}" # codebase:ignore mcr-scope — test records scrubbed env
  printf 'MISE_PROJECT_ROOT=%s\n' "${MISE_PROJECT_ROOT-}"
  printf 'MISE_TASK_NAME=%s\n' "${MISE_TASK_NAME-}"
  printf 'usage_headless=%s\n' "${usage_headless-}"
  printf 'usage_model=%s\n' "${usage_model-}"
  printf 'usage_message=%s\n' "${usage_message-}"
  printf 'GIT_AUTHOR_NAME=%s\n' "${GIT_AUTHOR_NAME-}"
  printf 'GIT_AUTHOR_EMAIL=%s\n' "${GIT_AUTHOR_EMAIL-}"
  printf 'PATH=%s\n' "${PATH-}"
} >> "${SESSIONS_ENV_LOG:-$SESSIONS_LOG.env}"
case "$1" in
  new) echo "mock-session-id-001" ;;
  meta)
    if [ "${MOCK_SESSION_META_FAIL:-false}" = "true" ]; then
      echo "mock sessions: metadata unavailable" >&2
      exit 1
    fi
    case "${4:-}" in
      .id) printf '%s\n' "$MOCK_SESSION_ID" ;;
      .cwd) printf '%s\n' "$MOCK_SESSION_CWD" ;;
      *) echo "mock sessions: unsupported meta field ${4:-}" >&2; exit 1 ;;
    esac
    ;;
  wake) ;;
  *) echo "mock sessions: unknown command $1" >&2; exit 1 ;;
esac
MOCK
  chmod +x "$MOCK_BIN/sessions"
  export PATH="$MOCK_BIN:$PATH"
}
