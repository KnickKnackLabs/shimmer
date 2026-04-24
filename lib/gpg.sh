#!/usr/bin/env bash
# Shared GPG helper functions for shimmer
#
# Sourced by gpg:setup and agent:sync-secrets.

# Strip wrapping double quotes from a value if present.
# Some secret providers (notably 1password CLI) may quote multiline values.
# Usage: value=$(strip_wrapping_quotes "$value")
strip_wrapping_quotes() {
  local value="$1"
  if [[ "$value" == \"*\" ]]; then
    value="${value#\"}"
    value="${value%\"}"
  fi
  printf '%s\n' "$value"
}

# Validate that a string is a parseable GPG key.
# Uses gpg --import --dry-run (no side effects).
# Returns 0 on success, 1 on failure with a diagnostic message on stderr.
# Usage: validate_gpg_key "$key_data"
validate_gpg_key() {
  local key_data="$1"

  if [ -z "$key_data" ]; then
    echo "GPG key is empty" >&2
    return 1
  fi

  # Check for leading quote (likely corrupted — wrapping quotes not fully stripped)
  if [[ "$key_data" == \"* ]]; then
    echo "GPG key starts with a double quote — likely corrupted" >&2
    return 1
  fi

  # Check for armor header
  if ! echo "$key_data" | head -1 | grep -q "^-----BEGIN PGP"; then
    local first_chars
    first_chars=$(echo "$key_data" | head -c 20)
    echo "GPG key doesn't start with PGP armor header (starts with: ${first_chars}...)" >&2
    return 1
  fi

  # Dry-run import to verify GPG can parse it
  local tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' RETURN
  printf '%s' "$key_data" > "$tmpfile"
  local output
  if ! output=$(gpg --batch --import --dry-run "$tmpfile" 2>&1); then
    echo "GPG cannot parse key: $output" >&2
    return 1
  fi
  return 0
}
