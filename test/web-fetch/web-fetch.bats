#!/usr/bin/env bats
# Tests for shimmer web:fetch

setup() {
  SHIMMER_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TASK="$SHIMMER_DIR/.mise/tasks/web/fetch"

  # Create a mock curl
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$MOCK_BIN"

  mock_curl '<html><body><h1>Hello</h1></body></html>'

  export PATH="$MOCK_BIN:$PATH"
}

# Helper: set up curl mock to return specific content
mock_curl() {
  local content="$1"
  cat > "$MOCK_BIN/curl" <<MOCK
#!/usr/bin/env bash
echo '$content'
MOCK
  chmod +x "$MOCK_BIN/curl"
}

# Helper: run the task with usage_ vars set
run_fetch() {
  local url=""
  local quiet="false"
  local header=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -q|--quiet) quiet="true"; shift ;;
      -H|--header) header="$2"; shift 2 ;;
      *) url="$1"; shift ;;
    esac
  done

  usage_url="$url" \
  usage_quiet="$quiet" \
  usage_header="${header:-}" \
  bash "$TASK"
}

# ============================================================================
# Basic functionality
# ============================================================================

@test "fetch: returns content from URL" {
  run run_fetch "https://example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello"* ]]
}

@test "fetch: shows fetching message on stderr by default" {
  run run_fetch "https://example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fetching: https://example.com"* ]]
}

@test "fetch: quiet mode suppresses fetching message" {
  run run_fetch -q "https://example.com"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Fetching:"* ]]
}

@test "fetch: returns raw HTML unchanged" {
  run run_fetch -q "https://example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<html>"* ]]
  [[ "$output" == *"<h1>Hello</h1>"* ]]
}

# ============================================================================
# Curl arguments
# ============================================================================

@test "fetch: follows redirects" {
  # Mock curl that captures args
  local argfile="$BATS_TEST_TMPDIR/curl-args"
  cat > "$MOCK_BIN/curl" <<MOCK
#!/usr/bin/env bash
echo "\$@" > "$argfile"
echo "ok"
MOCK
  chmod +x "$MOCK_BIN/curl"

  run run_fetch -q "https://example.com"
  [ "$status" -eq 0 ]
  grep -q "\-L" "$argfile"
}

@test "fetch: passes custom headers" {
  local argfile="$BATS_TEST_TMPDIR/curl-args"
  cat > "$MOCK_BIN/curl" <<MOCK
#!/usr/bin/env bash
echo "\$@" > "$argfile"
echo "ok"
MOCK
  chmod +x "$MOCK_BIN/curl"

  run run_fetch -q -H "Authorization: Bearer token123" "https://example.com"
  [ "$status" -eq 0 ]
  grep -q "Authorization: Bearer token123" "$argfile"
}

# ============================================================================
# Error handling
# ============================================================================

@test "fetch: fails on curl error" {
  cat > "$MOCK_BIN/curl" <<'MOCK'
#!/usr/bin/env bash
echo "curl: (6) Could not resolve host" >&2
exit 6
MOCK
  chmod +x "$MOCK_BIN/curl"

  run run_fetch -q "https://nonexistent.example.com"
  [ "$status" -ne 0 ]
}
