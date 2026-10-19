#!/usr/bin/env bash
# Shared GPG helper functions for shimmer
#
# Sourced by key setup, signing diagnostics, and agent:sync-secrets.

# Read only key metadata. A signing subkey must also have a usable primary.
gpg_secret_signing_fingerprints() {
  local listing
  listing=$(gpg --batch --no-tty \
    --with-colons --with-fingerprint --with-subkey-fingerprint \
    --list-secret-keys "$@" 2>/dev/null) || return 1

  printf '%s\n' "$listing" | awk -F: -v now="$(date +%s)" '
    function usable(validity, expiry, capabilities) {
      return validity !~ /[redi]/ && capabilities !~ /D/ &&
        (expiry == "" || expiry == "0" || expiry > now)
    }
    $1 == "sec" || $1 == "ssb" {
      key_ok = usable($2, $7, $12)
      if ($1 == "sec") primary_ok = key_ok
      else key_ok = primary_ok && key_ok
      signing = key_ok && $12 ~ /s/ && $15 != "#"
      next
    }
    $1 == "fpr" {
      if (signing) print toupper($10)
      signing = 0
    }
  '
}

# Report the effective caller Git configuration, including persona overrides.
# This is observational: no import, signing, credential retrieval, or Git writes.
git_signing_status() {
  local caller="${SHIMMER_CALLER_PWD:-$PWD}" fingerprint format commits tags available
  fingerprint=$(git -C "$caller" config user.signingkey 2>/dev/null) || fingerprint=''
  fingerprint="${fingerprint%!}"
  if [[ ! "$fingerprint" =~ ^([A-Fa-f0-9]{40}|[A-Fa-f0-9]{64})$ ]]; then
    echo "full signing fingerprint not configured"
    return 1
  fi

  format=$(git -C "$caller" config gpg.format 2>/dev/null) || format=openpgp
  if [ "$format" != openpgp ]; then
    echo "Git signing format is not OpenPGP"
    return 1
  fi
  commits=$(git -C "$caller" config --bool commit.gpgsign 2>/dev/null) || commits=false
  tags=$(git -C "$caller" config --bool tag.gpgsign 2>/dev/null) || tags=false
  if [ "$commits" != true ] || [ "$tags" != true ]; then
    echo "commit or tag signing disabled"
    return 1
  fi

  if ! available=$(gpg_secret_signing_fingerprints "$fingerprint"); then
    echo "could not inspect secret signing key"
    return 1
  fi
  fingerprint=$(printf '%s' "$fingerprint" | tr '[:lower:]' '[:upper:]')
  if ! grep -Fx "$fingerprint" <<< "$available" >/dev/null; then
    echo "configured signer has no usable secret signing key"
    return 1
  fi
  printf 'signing enabled (%s)\n' "$fingerprint"
}

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
  if [[ "$key_data" != '-----BEGIN PGP'* ]]; then
    local first_chars="${key_data:0:20}"
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
