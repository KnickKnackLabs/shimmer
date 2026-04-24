# Helpers for shimmer GPG BATS tests

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.bash"

# Generate a real GPG key for testing.
# Uses a short socket path to avoid gpg-agent socket length limits.
# Sets VALID_GPG_KEY (armor) and TEST_GNUPGHOME.
generate_test_gpg_key() {
  # gpg-agent fails if the socket path exceeds ~104 chars.
  # BATS_TEST_TMPDIR can be very long, so use /tmp instead.
  local keygen_dir="/tmp/bats-gpg-keygen-$$"
  mkdir -p "$keygen_dir"
  chmod 700 "$keygen_dir"

  GNUPGHOME="$keygen_dir" gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Name-Real: Test Agent
Name-Email: test@ricon.family
Expire-Date: 0
%commit
EOF

  VALID_GPG_KEY=$(GNUPGHOME="$keygen_dir" gpg --armor --export-secret-keys test@ricon.family 2>/dev/null)
  export VALID_GPG_KEY

  # Clean up keygen dir — tests use their own GNUPGHOME.
  # Only try to kill the agent if one is running under this homedir.
  if [ -S "$keygen_dir/S.gpg-agent" ]; then
    gpgconf --homedir "$keygen_dir" --kill gpg-agent 2>/dev/null
  fi
  rm -rf "$keygen_dir"

  # Set up a clean GNUPGHOME for the test itself (also short path)
  TEST_GNUPGHOME="/tmp/bats-gpg-test-$$"
  mkdir -p "$TEST_GNUPGHOME"
  chmod 700 "$TEST_GNUPGHOME"
  export GNUPGHOME="$TEST_GNUPGHOME"
}

# Wrap a value in literal double quotes (simulates the corruption).
# Usage: quoted=$(quote_wrap "$value")
quote_wrap() {
  printf '"%s"' "$1"
}

# Clean up gpg-agent and temp dirs.
cleanup_test_gpg() {
  # Only try to kill the agent if a socket exists (avoids gpgconf failing on
  # a never-started agent).
  if [ -n "${TEST_GNUPGHOME:-}" ] && [ -S "$TEST_GNUPGHOME/S.gpg-agent" ]; then
    gpgconf --homedir "$TEST_GNUPGHOME" --kill gpg-agent 2>/dev/null
  fi
  # rm -rf is already idempotent on missing paths — no swallow needed.
  rm -rf "${TEST_GNUPGHOME:-}"
}
