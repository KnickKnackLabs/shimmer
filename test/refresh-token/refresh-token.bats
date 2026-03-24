#!/usr/bin/env bats
# Tests for OAuth token extraction from claude setup-token output.
#
# The token extraction must handle:
# - ANSI escape sequences (CSI, OSC hyperlinks, mode switches)
# - Unicode block art characters
# - Line-wrapped tokens
# - Surrounding prose

# The extraction logic under test
extract_token() {
  local raw="$1"
  local cleaned
  cleaned=$(printf '%s' "$raw" | LC_ALL=C tr -cd '[:print:]\n' | tr -d '\n')
  echo "$cleaned" | grep -o 'sk-ant-oat01-[A-Za-z0-9_-]*AA'
}

# --- Clean token on a single line ---

@test "extracts token from clean single-line output" {
  local input="Your OAuth token: sk-ant-oat01-abc123DEF_456-xyzAA done."
  run extract_token "$input"
  [ "$status" -eq 0 ]
  [ "$output" = "sk-ant-oat01-abc123DEF_456-xyzAA" ]
}

# --- Token wrapped across two lines ---

@test "extracts token split across two lines" {
  local input="Your OAuth token:

sk-ant-oat01-UrD-W7nbdm3WX1aBGGP307_CqP35e892Knft0X20R4UvvNzwazoLuGQYuLr7frMnS8V
80mMgoKOCQLAAcq-D1w--M4CagAA

Store this token securely."
  run extract_token "$input"
  [ "$status" -eq 0 ]
  [ "$output" = "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" ]
}

# --- ANSI CSI escape sequences ---

@test "strips ANSI CSI sequences" {
  local input=$'\x1b[32msk-ant-oat01-cleanAA\x1b[0m'
  run extract_token "$input"
  [ "$status" -eq 0 ]
  [ "$output" = "sk-ant-oat01-cleanAA" ]
}

# --- OSC hyperlink sequences ---

@test "strips OSC 8 hyperlink sequences" {
  local input=$'\x1b]8;;https://example.com\x07sk-ant-oat01-linkAA\x1b]8;;\x07'
  run extract_token "$input"
  [ "$status" -eq 0 ]
  [ "$output" = "sk-ant-oat01-linkAA" ]
}

# --- Mode switch sequences ---

@test "strips terminal mode switch sequences" {
  local input=$'\x1b[?2026hsk-ant-oat01-modeAA\x1b[?2026l'
  run extract_token "$input"
  [ "$status" -eq 0 ]
  [ "$output" = "sk-ant-oat01-modeAA" ]
}

# --- Unicode block art (high bytes stripped) ---

@test "strips Unicode block art characters" {
  # Simulate the █▓░ characters that claude setup-token outputs
  local input=$'█▓░ sk-ant-oat01-unicodeAA ░▓█'
  run extract_token "$input"
  [ "$status" -eq 0 ]
  [ "$output" = "sk-ant-oat01-unicodeAA" ]
}

# --- Full realistic output (kitchen sink) ---

@test "extracts token from realistic claude setup-token output" {
  local input=$'\x1b[?2026hWelcome to Claude Code\n'
  input+=$'████▓▓░\n'
  input+=$'\x1b]8;;https://claude.ai\x07link\x1b]8;;\x07\n'
  input+=$'Long-lived authentication token created successfully!\n'
  input+=$'\n'
  input+=$'Your OAuth token (valid for 1 year):\n'
  input+=$'\n'
  input+=$'sk-ant-oat01-UrD-W7nbdm3WX1aBGGP307_CqP35e892Knft0X20R4UvvNzwazoLuGQYuLr\n'
  input+=$'7frMnS8V80mMgoKOCQLAAcq-D1w--M4CagAA\n'
  input+=$'\n'
  input+=$'Store this token securely.\n'
  input+=$'\x1b[?2026l'
  run extract_token "$input"
  [ "$status" -eq 0 ]
  [ "$output" = "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" ]
}

# --- No token present ---

@test "fails when no token in output" {
  local input="No token here, just garbage."
  run extract_token "$input"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

# --- Carriage returns ---

@test "handles carriage returns in output" {
  local input=$'sk-ant-oat01-crlfAA\r\n'
  run extract_token "$input"
  [ "$status" -eq 0 ]
  [ "$output" = "sk-ant-oat01-crlfAA" ]
}
