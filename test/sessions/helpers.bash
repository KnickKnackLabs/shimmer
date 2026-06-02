# Helpers for shimmer sessions:* BATS tests

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.bash"

# Create mock `sessions`, `blobs`, and `secrets` binaries for sessions:backup tests.
# Usage: mock_sessions_backup_tools '[{"session_id":"s1"}]'
mock_sessions_backup_tools() {
  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  SESSIONS_LIST_JSON="${1:-[]}"
  SESSIONS_LOG="$BATS_TEST_TMPDIR/sessions-log-$$"
  BLOBS_LOG="$BATS_TEST_TMPDIR/blobs-log-$$"
  export SESSIONS_LIST_JSON SESSIONS_LOG BLOBS_LOG

  cat > "$MOCK_BIN/sessions" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$SESSIONS_LOG"
case "$1" in
  list)
    case "$SESSIONS_LIST_JSON" in
      __FAIL__)
        echo "mock list failure" >&2
        exit 42
        ;;
      __NO_SESSIONS_DIR__)
        echo "No sessions directory at /tmp/mock-pi/agent/sessions" >&2
        exit 1
        ;;
      *)
        printf '%s\n' "$SESSIONS_LIST_JSON"
        ;;
    esac
    ;;
  export)
    output=""
    session_id=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --output)
          output="$2"
          shift 2
          ;;
        --format)
          shift 2
          ;;
        export)
          shift
          ;;
        *)
          session_id="$1"
          shift
          ;;
      esac
    done
    [ -n "$output" ] || { echo "mock sessions: missing --output" >&2; exit 1; }
    [ -n "$session_id" ] || { echo "mock sessions: missing session id" >&2; exit 1; }
    mkdir -p "$output/$session_id"
    printf '{"type":"session","id":"%s"}\n' "$session_id" > "$output/$session_id/$session_id.jsonl"
    printf '{"session_id":"%s"}\n' "$session_id" > "$output/$session_id/metadata.json"
    ;;
  *)
    echo "mock sessions: unknown command $1" >&2
    exit 1
    ;;
esac
MOCK
  chmod +x "$MOCK_BIN/sessions"

  cat > "$MOCK_BIN/blobs" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$BLOBS_LOG"
MOCK
  chmod +x "$MOCK_BIN/blobs"

  cat > "$MOCK_BIN/secrets" <<'MOCK'
#!/usr/bin/env bash
case "$1:$2" in
  get:test-agent/b2-endpoint) echo "https://example.invalid" ;;
  get:test-agent/b2-key-id) echo "key-id" ;;
  get:test-agent/b2-application-key) echo "application-key" ;;
  get:test-agent/b2-bucket) echo "bucket" ;;
  *) echo "missing secret $*" >&2; exit 1 ;;
esac
MOCK
  chmod +x "$MOCK_BIN/secrets"

  export PATH="$MOCK_BIN:$PATH"
}
