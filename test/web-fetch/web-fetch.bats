#!/usr/bin/env bats
# Tests for shimmer web:fetch
#
# Standalone by design: doesn't source test/helpers.bash because these
# tests don't need the mock-first overlay machinery — they only need a
# PATH-level mock of `curl`. The web:* tasks are slated for extraction
# into a separate `web` codebase (KnickKnackLabs/web), at which point
# these tests move with them, so tying into shimmer's shared helpers
# would be wasted work.
#
# Hazard: the PATH-level curl mock relies on shimmer's mise.toml not
# pinning `curl` as a tool. If it ever does, mise's prepended shim dir
# would shadow $MOCK_BIN and silently break the mock.

setup() {
  SHIMMER_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

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

# Helper: run the task through mise, so USAGE parses flags like real usage.
run_fetch() {
  mise -C "$SHIMMER_DIR" run -q web:fetch "$@"
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
