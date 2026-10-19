#!/usr/bin/env bats

load helpers.bash

setup() {
  generate_test_gpg_key
  mock_shimmer
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME='Test Persona' GIT_AUTHOR_EMAIL=test@example.test
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  export SHIMMER_CALLER_PWD="$OVERLAY"
  git -C "$OVERLAY" config user.signingkey "$GPG_FINGERPRINT"
  git -C "$OVERLAY" config commit.gpgsign true
  git -C "$OVERLAY" config tag.gpgsign true
  printf '%s' "$VALID_GPG_KEY" | gpg --batch --import >/dev/null 2>&1
}

teardown() {
  cleanup_test_gpg
}

@test "status uses effective process signing overrides, not repository or workspace defaults" {
  git -C "$OVERLAY" config user.signingkey BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=user.signingkey GIT_CONFIG_VALUE_0="$GPG_FINGERPRINT"

  run shimmer gpg:status

  [ "$status" -eq 0 ]
  [[ "$output" == *"Test Persona <test@example.test>"* ]]
  [[ "$output" == *"signing enabled ($GPG_FINGERPRINT)"* ]]
}

@test "status uses matching account defaults outside an activated process" {
  git -C "$OVERLAY" config --unset user.signingkey
  git config --global user.signingkey "$GPG_FINGERPRINT"

  run shimmer gpg:status

  [ "$status" -eq 0 ]
  [[ "$output" == *"signing enabled ($GPG_FINGERPRINT)"* ]]
}

@test "status rejects a different effective signer even when an agent key is imported" {
  git -C "$OVERLAY" config user.signingkey BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB

  run shimmer gpg:status test

  [ "$status" -ne 0 ]
  [[ "$output" == *"could not inspect secret signing key"* ]]
}

@test "status rejects disabled commit or tag signing" {
  local setting
  for setting in commit.gpgsign tag.gpgsign; do
    git -C "$OVERLAY" config "$setting" false

    run shimmer gpg:status

    [ "$status" -ne 0 ]
    [[ "$output" == *"commit or tag signing disabled"* ]]
    git -C "$OVERLAY" config "$setting" true
  done
}

@test "status rejects a missing signing fingerprint" {
  git -C "$OVERLAY" config --unset user.signingkey

  run shimmer gpg:status

  [ "$status" -ne 0 ]
  [[ "$output" == *"full signing fingerprint not configured"* ]]
}

@test "status rejects a non-OpenPGP signing format" {
  git -C "$OVERLAY" config gpg.format ssh

  run shimmer gpg:status

  [ "$status" -ne 0 ]
  [[ "$output" == *"Git signing format is not OpenPGP"* ]]
}

@test "status accepts an exact GnuPG fingerprint selector" {
  git -C "$OVERLAY" config user.signingkey "$GPG_FINGERPRINT!"

  run shimmer gpg:status

  [ "$status" -eq 0 ]
  [[ "$output" == *"signing enabled ($GPG_FINGERPRINT)"* ]]
}

@test "welcome reports the same effective signer without accessing live services" {
  export GIT_AUTHOR_EMAIL=test@ricon.family
  export HIMALAYA_CONFIG="$BATS_TEST_TMPDIR/missing-mail-config"
  export GH_TOKEN=''

  run shimmer welcome

  [ "$status" -eq 0 ]
  [[ "$output" == *"signing enabled ($GPG_FINGERPRINT)"* ]]
  [[ "$output" != *"GPG  ✗"* ]]
}

@test "setup preserves existing Git configuration and creates no workspace configuration" {
  # Preserve Mise's own directories while isolating the task's HOME writes.
  export MISE_DATA_DIR="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}"
  export MISE_CONFIG_DIR="${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}"
  export MISE_STATE_DIR="${MISE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/mise}"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/agents/test"
  printf 'legacy config\n' > "$HOME/agents/test/.gitconfig"
  cp "$HOME/agents/test/.gitconfig" "$BATS_TEST_TMPDIR/legacy-before"
  git config --global user.name 'Account Owner'
  cp "$GIT_CONFIG_GLOBAL" "$BATS_TEST_TMPDIR/global-before"

  run shimmer gpg:setup test

  [ "$status" -eq 0 ]
  [[ "$output" == *"already imported"* ]]
  cmp "$GIT_CONFIG_GLOBAL" "$BATS_TEST_TMPDIR/global-before"
  cmp "$HOME/agents/test/.gitconfig" "$BATS_TEST_TMPDIR/legacy-before"

  run shimmer gpg:setup another-handle

  [ "$status" -eq 0 ]
  [ ! -e "$HOME/agents/another-handle" ]
}

@test "setup reads only signer metadata when its key is already present" {
  export TEST_SIGNER="$GPG_FINGERPRINT" MOCK_CALLS="$BATS_TEST_TMPDIR/secrets-calls"
  unset GPG_FINGERPRINT
  # shellcheck disable=SC2329
  secrets() {
    printf '%s\n' "$*" >> "$MOCK_CALLS"
    [ "$*" = 'get test/git/signing-fingerprint' ] || return 1
    printf '%s\n' "$TEST_SIGNER"
  }
  export -f secrets

  run shimmer gpg:setup test

  [ "$status" -eq 0 ]
  [ "$(wc -l < "$MOCK_CALLS" | tr -d ' ')" = 1 ]
}

@test "setup delegates both credential reads to the caller's selected provider" {
  export TEST_SIGNER="$GPG_FINGERPRINT" MOCK_CALLS="$BATS_TEST_TMPDIR/secrets-calls"
  # Select the fixture's provider without inheriting the host's Mise env setting.
  printf '\n[env]\nSECRETS_PROVIDER = "{{env.TEST_PROVIDER}}"\n' >> "$OVERLAY/mise.toml"
  unset GPG_FINGERPRINT GPG_PRIVATE_KEY
  # shellcheck disable=SC2329
  secrets() {
    printf '%s %s\n' "${SECRETS_PROVIDER:-}" "$*" >> "$MOCK_CALLS"
    case "$*" in
      'get test/git/signing-fingerprint') printf '%s' "$TEST_SIGNER" ;;
      'get test/gpg-private-key') printf '%s' "$VALID_GPG_KEY" ;;
      *) return 1 ;;
    esac
  }
  export -f secrets
  local provider
  for provider in sops 1password; do
    export TEST_PROVIDER="$provider"
    gpg --batch --yes --delete-secret-and-public-key "$TEST_SIGNER"
    : > "$MOCK_CALLS"

    run shimmer gpg:setup test

    [ "$status" -eq 0 ]
    [ "$(wc -l < "$MOCK_CALLS" | tr -d ' ')" = 2 ]
    grep -Fx "$provider get test/git/signing-fingerprint" "$MOCK_CALLS"
    grep -Fx "$provider get test/gpg-private-key" "$MOCK_CALLS"
  done
}

@test "setup stops after a provider failure without trying another provider" {
  export MOCK_CALLS="$BATS_TEST_TMPDIR/secrets-calls" SECRETS_PROVIDER=sops
  unset GPG_FINGERPRINT GPG_PRIVATE_KEY
  # shellcheck disable=SC2329
  secrets() {
    printf '%s %s\n' "$SECRETS_PROVIDER" "$*" >> "$MOCK_CALLS"
    return 1
  }
  export -f secrets

  run shimmer gpg:setup test

  [ "$status" -ne 0 ]
  [ "$(< "$MOCK_CALLS")" = 'sops get test/git/signing-fingerprint' ]
}

@test "setup imports an exact signing subkey and trusts its primary" {
  primary="$GPG_FINGERPRINT"
  gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-add-key "$primary" rsa2048 sign 0
  export GPG_PRIVATE_KEY=$(gpg --armor --export-secret-keys "$primary" 2>/dev/null)
  GPG_FINGERPRINT=$(gpg --with-colons --list-secret-keys "$primary" 2>/dev/null |
    awk -F: '$1 == "ssb" {subkey = 1} subkey && $1 == "fpr" {print $10; exit}')
  export GPG_FINGERPRINT
  gpg --batch --yes --delete-secret-and-public-key "$primary"

  run shimmer gpg:setup test

  [ "$status" -eq 0 ]
  [[ "$output" == *"GPG key ready for test"* ]]
  gpg --export-ownertrust 2>/dev/null | grep -Fx "$primary:6:"
}

@test "setup refuses to import a private key for a different fingerprint" {
  export GPG_FINGERPRINT=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
  export GPG_PRIVATE_KEY="$VALID_GPG_KEY"
  before=$(gpg --with-colons --list-secret-keys 2>/dev/null)

  run shimmer gpg:setup test

  [ "$status" -ne 0 ]
  [[ "$output" == *"private key does not match"* ]]
  [ "$(gpg --with-colons --list-secret-keys 2>/dev/null)" = "$before" ]
}
