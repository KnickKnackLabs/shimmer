# Helpers for ci:dispatch BATS tests

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.bash"

# Create a mock `gh` binary that logs calls and returns canned responses.
# Usage: mock_gh [run_id] [delay_polls]
#   run_id: the run ID to return (default: 12345)
#   delay_polls: number of polls before the run appears (default: 0)
mock_gh() {
  local run_id="${1:-12345}"
  local delay_polls="${2:-0}"

  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  GH_LOG="$BATS_TEST_TMPDIR/gh-log-$$"
  GH_POLL_COUNT="$BATS_TEST_TMPDIR/gh-poll-count-$$"
  SLEEP_LOG="$BATS_TEST_TMPDIR/sleep-log-$$"
  echo "0" > "$GH_POLL_COUNT"
  : > "$SLEEP_LOG"
  export GH_LOG GH_POLL_COUNT SLEEP_LOG

  cat > "$MOCK_BIN/sleep" <<'MOCK_SLEEP'
#!/usr/bin/env bash
echo "$@" >> "$SLEEP_LOG"
MOCK_SLEEP
  chmod +x "$MOCK_BIN/sleep"

  cat > "$MOCK_BIN/gh" <<MOCK
#!/usr/bin/env bash
echo "\$@" >> "$GH_LOG"

case "\$1" in
  workflow)
    # gh workflow run — just succeed
    ;;
  run)
    case "\$2" in
      list)
        # Increment poll counter
        COUNT=\$(cat "$GH_POLL_COUNT")
        COUNT=\$((COUNT + 1))
        echo "\$COUNT" > "$GH_POLL_COUNT"

        if [ "\$COUNT" -le "$delay_polls" ]; then
          # Run hasn't appeared yet
          echo "[]"
        else
          # Return a run with a recent timestamp
          echo '[{"databaseId": $run_id, "createdAt": "2099-01-01T00:00:00Z", "url": "https://github.com/test/repo/actions/runs/$run_id"}]'
        fi
        ;;
    esac
    ;;
  api)
    # gh api user — return mock user
    echo "mock-user"
    ;;
esac
MOCK
  chmod +x "$MOCK_BIN/gh"
  export PATH="$MOCK_BIN:$PATH"
  export GH_BIN="$MOCK_BIN/gh"
}

# Create a mock gh that never returns a run (for timeout testing)
mock_gh_no_runs() {
  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  GH_LOG="$BATS_TEST_TMPDIR/gh-log-$$"
  SLEEP_LOG="$BATS_TEST_TMPDIR/sleep-log-$$"
  : > "$SLEEP_LOG"
  export GH_LOG SLEEP_LOG

  cat > "$MOCK_BIN/sleep" <<'MOCK_SLEEP'
#!/usr/bin/env bash
echo "$@" >> "$SLEEP_LOG"
MOCK_SLEEP
  chmod +x "$MOCK_BIN/sleep"

  cat > "$MOCK_BIN/gh" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$GH_LOG"

case "$1" in
  workflow) ;;
  run)
    case "$2" in
      list) echo "[]" ;;
    esac
    ;;
  api) echo "mock-user" ;;
esac
MOCK
  chmod +x "$MOCK_BIN/gh"
  export PATH="$MOCK_BIN:$PATH"
  export GH_BIN="$MOCK_BIN/gh"
}
