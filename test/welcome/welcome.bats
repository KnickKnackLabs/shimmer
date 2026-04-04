#!/usr/bin/env bats

setup() {
  load helpers
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$MOCK_BIN"
  export PATH="$MOCK_BIN:$PATH"
}

# Create a mock `emails` binary with custom behavior per subcommand.
# Usage: mock_emails "quota" 'echo "Usage: 42%"'
#        mock_emails "list"  'echo "5"'
# Call multiple times to build up the mock. Each call adds a case branch.
# Call mock_emails_finish when done to write the final script.
mock_emails_start() {
  cat > "$MOCK_BIN/emails" << 'HEADER'
#!/usr/bin/env bash
case "$1" in
HEADER
}

mock_emails_case() {
  local subcmd="$1" body="$2"
  echo "  $subcmd) $body ;;" >> "$MOCK_BIN/emails"
}

mock_emails_finish() {
  cat >> "$MOCK_BIN/emails" << 'FOOTER'
esac
FOOTER
  chmod +x "$MOCK_BIN/emails"
}

# Convenience: mock emails to fail with a specific exit code
mock_emails_fail() {
  local code="$1"
  cat > "$MOCK_BIN/emails" << SCRIPT
#!/usr/bin/env bash
exit $code
SCRIPT
  chmod +x "$MOCK_BIN/emails"
}

@test "email: not configured when no himalaya config" {
  export AGENT="test-agent"
  export HIMALAYA_CONFIG="$BATS_TEST_TMPDIR/nonexistent.toml"

  run check_email
  [[ "$output" == *"✗"* ]]
  [[ "$output" == *"not configured"* ]]
}

@test "email: timed out after 5s when server unreachable" {
  setup_email
  mock_emails_fail 124

  run check_email
  [[ "$output" == *"✗"* ]]
  [[ "$output" == *"timed out after 5s"* ]]
}

@test "email: check failed on non-timeout error" {
  setup_email
  mock_emails_fail 1

  run check_email
  [[ "$output" == *"✗"* ]]
  [[ "$output" == *"check failed"* ]]
}

@test "email: success with unread and low quota" {
  setup_email
  mock_emails_start
  mock_emails_case "quota" 'echo "Usage: 42%"'
  mock_emails_case "list" 'echo "5"'
  mock_emails_finish

  run check_email
  [[ "$output" == *"✓"* ]]
  [[ "$output" == *"5 unread"* ]]
  [[ "$output" == *"quota 42%"* ]]
}

@test "email: success with zero unread" {
  setup_email
  mock_emails_start
  mock_emails_case "quota" 'echo "Usage: 10%"'
  mock_emails_case "list" 'echo "0"'
  mock_emails_finish

  run check_email
  [[ "$output" == *"✓"* ]]
  [[ "$output" == *"0 unread"* ]]
}

@test "email: warning when quota >= 80%" {
  setup_email
  mock_emails_start
  mock_emails_case "quota" 'echo "Usage: 85%"'
  mock_emails_case "list" 'echo "2"'
  mock_emails_finish

  run check_email
  [[ "$output" == *"⚠"* ]]
  [[ "$output" == *"2 unread"* ]]
  [[ "$output" == *"quota 85%"* ]]
}

@test "email: critical when quota >= 95%" {
  setup_email
  mock_emails_start
  mock_emails_case "quota" 'echo "Usage: 97%"'
  mock_emails_case "list" 'echo "12"'
  mock_emails_finish

  run check_email
  [[ "$output" == *"✗"* ]]
  [[ "$output" == *"12 unread"* ]]
  [[ "$output" == *"quota 97%"* ]]
  [[ "$output" == *"emails purge"* ]]
}
