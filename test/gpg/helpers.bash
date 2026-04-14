# Helpers for shimmer GPG BATS tests

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.bash"

# Generate a real GPG key for testing.
# Uses a temporary GNUPGHOME so it doesn't pollute the real keyring.
# Sets VALID_GPG_KEY (armor) and TEST_GNUPGHOME.
# Usage: generate_test_gpg_key
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

  # Clean up keygen dir — tests use their own GNUPGHOME
  gpgconf --homedir "$keygen_dir" --kill gpg-agent 2>/dev/null || true
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
  echo "\"$1\""
}

# Clean up gpg-agent and temp dirs.
cleanup_test_gpg() {
  gpgconf --homedir "${TEST_GNUPGHOME:-/nonexistent}" --kill gpg-agent 2>/dev/null || true
  rm -rf "${TEST_GNUPGHOME:-}" 2>/dev/null || true
}
