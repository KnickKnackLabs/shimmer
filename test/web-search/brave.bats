#!/usr/bin/env bats
# Tests for shimmer web:search:brave

setup() {
  SHIMMER_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"

  # Create a mock curl that returns fixture data
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$MOCK_BIN"

  # Default: return the standard fixture
  mock_curl "$FIXTURES/brave-response.json"

  export PATH="$MOCK_BIN:$PATH"
  export BRAVE_SEARCH_API_KEY="test-key-123"

  TASK="$SHIMMER_DIR/.mise/tasks/web/search/brave"
}

# Helper: set up curl mock to return a specific fixture
mock_curl() {
  local fixture="$1"
  cat > "$MOCK_BIN/curl" <<MOCK
#!/usr/bin/env bash
cat "$fixture"
MOCK
  chmod +x "$MOCK_BIN/curl"
}

# Helper: run the task with usage_ vars set (simulating mise's USAGE parsing)
run_brave() {
  local json="false"
  local count="5"
  local offset="0"
  local query=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json="true"; shift ;;
      -n) count="$2"; shift 2 ;;
      --offset) offset="$2"; shift 2 ;;
      *) query="$query $1"; shift ;;
    esac
  done
  query="${query# }"  # trim leading space

  usage_query="$query" \
  usage_json="$json" \
  usage_count="$count" \
  usage_offset="$offset" \
  bash "$TASK"
}

# ============================================================================
# JSON output
# ============================================================================

@test "json: returns web results array" {
  run run_brave --json test query
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 3'
}

@test "json: preserves all fields" {
  run run_brave --json test query
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].title == "First Result Title"'
  echo "$output" | jq -e '.[0].url == "https://example.com/first"'
}

@test "json: empty results returns empty array" {
  mock_curl "$FIXTURES/brave-empty.json"
  run run_brave --json test query
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 0'
}

# ============================================================================
# Formatted output
# ============================================================================

@test "format: shows numbered results" {
  run run_brave test query
  [ "$status" -eq 0 ]
  [[ "$output" == *"1. First Result Title"* ]]
  [[ "$output" == *"2. Second Result"* ]]
  [[ "$output" == *"3. No Description Result"* ]]
}

@test "format: shows URLs" {
  run run_brave test query
  [ "$status" -eq 0 ]
  [[ "$output" == *"https://example.com/first"* ]]
  [[ "$output" == *"https://example.com/second"* ]]
}

@test "format: strips HTML tags from descriptions" {
  run run_brave test query
  [ "$status" -eq 0 ]
  [[ "$output" == *"bold HTML"* ]]
  [[ "$output" != *"<b>"* ]]
  [[ "$output" != *"</b>"* ]]
}

@test "format: decodes HTML entities" {
  run run_brave test query
  [ "$status" -eq 0 ]
  # &quot; → "
  [[ "$output" == *'"quotes"'* ]]
  # &#x27; → '
  [[ "$output" == *"'apostrophes'"* ]]
  # &amp; → &
  [[ "$output" == *"& ampersands"* ]]
  # &lt; and &gt; → < >
  [[ "$output" == *"<angle brackets>"* ]]
}

@test "format: handles missing description" {
  run run_brave test query
  [ "$status" -eq 0 ]
  [[ "$output" == *"3. No Description Result"* ]]
  [[ "$output" == *"https://example.com/no-desc"* ]]
}

@test "format: empty results shows message" {
  mock_curl "$FIXTURES/brave-empty.json"
  run run_brave test query
  [ "$status" -eq 0 ]
  [[ "$output" == *"No results found"* ]]
}

# ============================================================================
# Error handling
# ============================================================================

@test "error: missing API key" {
  unset BRAVE_SEARCH_API_KEY
  run run_brave test query
  [ "$status" -ne 0 ]
  [[ "$output" == *"BRAVE_SEARCH_API_KEY not set"* ]]
}

@test "error: API error response" {
  mock_curl "$FIXTURES/brave-error.json"
  run run_brave test query
  [ "$status" -ne 0 ]
  [[ "$output" == *"API key is invalid"* ]]
}

@test "error: non-JSON response (HTML proxy page, 502, etc.)" {
  echo '<html><body>502 Bad Gateway</body></html>' > "$BATS_TEST_TMPDIR/html-response"
  mock_curl "$BATS_TEST_TMPDIR/html-response"
  run run_brave test query
  [ "$status" -ne 0 ]
  [[ "$output" == *"unexpected response (not JSON)"* ]]
  [[ "$output" == *"502 Bad Gateway"* ]]
}

@test "offset: passes through to curl" {
  # Mock curl that captures args and returns fixture
  local fixture="$FIXTURES/brave-response.json"
  local argfile="$BATS_TEST_TMPDIR/curl-args"
  printf '#!/usr/bin/env bash\necho "$@" > %s\ncat %s\n' "$argfile" "$fixture" > "$MOCK_BIN/curl"
  chmod +x "$MOCK_BIN/curl"
  run run_brave --offset 10 test query
  [ "$status" -eq 0 ]
  grep -q "offset=10" "$argfile"
}
