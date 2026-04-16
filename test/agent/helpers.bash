# Helpers for shimmer agent BATS tests
#
# Uses the mock-first include overlay pattern from test/helpers.bash.
# Mocks `sessions` and `pi` binaries to test agent task branching
# without real session infrastructure.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.bash"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../ci" && pwd)/helpers.bash"

# Set up minimal agent identity environment.
# Usage: setup_agent [name]
setup_agent() {
  local name="${1:-test-agent}"
  export GIT_AUTHOR_NAME="$name"
  export GIT_AUTHOR_EMAIL="${name}@ricon.family"
  export AGENT_IDENTITY="You are ${name}."
  export CALLER_PWD="$BATS_TEST_TMPDIR"
}

# Create a mock `sessions` binary on PATH.
# Records calls to a log file for assertion.
# Usage: mock_sessions_binary
mock_sessions_binary() {
  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  SESSIONS_LOG="$BATS_TEST_TMPDIR/sessions-log-$$"
  export SESSIONS_LOG

  cat > "$MOCK_BIN/sessions" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$SESSIONS_LOG"
case "$1" in
  new) echo "mock-session-id-001" ;;
  wake) ;;
  *) echo "mock sessions: unknown command $1" >&2; exit 1 ;;
esac
MOCK
  chmod +x "$MOCK_BIN/sessions"
  export PATH="$MOCK_BIN:$PATH"
}

# Create a mock harness binary and set AGENT_HARNESS to point at it.
# This avoids PATH ordering issues with mise-managed tools.
# Usage: mock_harness
mock_harness() {
  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  HARNESS_LOG="$BATS_TEST_TMPDIR/harness-log-$$"
  export HARNESS_LOG

  cat > "$MOCK_BIN/mock-harness" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$HARNESS_LOG"
MOCK
  chmod +x "$MOCK_BIN/mock-harness"
  export PATH="$MOCK_BIN:$PATH"
  export AGENT_HARNESS="mock-harness"
}
