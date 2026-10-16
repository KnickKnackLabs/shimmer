#!/usr/bin/env bats
# Synthetic vault/key metadata. Public routing tests use real Mise, never a vault.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_DIR
  source "$REPO_DIR/lib/persona/activate.sh"
  local name
  for name in $(compgen -e); do
    case "$name" in
      GIT_CONFIG_*|GIT_AUTHOR_*|GIT_COMMITTER_*|GH_TOKEN|GH_HOST|SHIMMER_PERSONA_STATE|EMAIL_*|BLOBS_*) unset "$name" ;;
    esac
  done
  export MOCK_BUNDLE_FILE="$BATS_TEST_TMPDIR/bundle.json"
  export MOCK_KEYS_FILE="$BATS_TEST_TMPDIR/keys"
  export MOCK_CALLS="$BATS_TEST_TMPDIR/calls"
  export MOCK_SECRETS_STATUS=0
  export MOCK_GPG_STATUS=0
  export AGENT_HOME=/caller/selected/home
  STDOUT="$BATS_TEST_TMPDIR/stdout"
  STDERR="$BATS_TEST_TMPDIR/stderr"
  bundle Alice synthetic-token
  key AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

  # Exported mocks are invoked by activation and by the public Mise task.
  # shellcheck disable=SC2329
  secrets() {
    printf '%s\n' "$*" >> "$MOCK_CALLS"
    [ "$MOCK_SECRETS_STATUS" = 0 ] || return 1
    # Files contain synthetic data only.
    while IFS= read -r line; do
      printf '%s\n' "$line"
    done < "$MOCK_BUNDLE_FILE"
  }
  # shellcheck disable=SC2329
  gpg() {
    printf '%s\n' "$*" >> "$MOCK_CALLS"
    [ "$MOCK_GPG_STATUS" = 0 ] || return 1
    while IFS= read -r line; do
      printf '%s\n' "$line"
    done < "$MOCK_KEYS_FILE"
  }
  export -f secrets gpg
}

bundle() {
  jq -cn --arg name "$1" --arg token "${2:-}" '{
    "alice/git/name": $name,
    "alice/git/email": "alice@example.test",
    "alice/git/signing-fingerprint": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    "alice/github/token": $token
  }' > "$MOCK_BUNDLE_FILE"
}

key() {
  printf 'sec:u:2048:1:123:1:0:::::scSC:::+:\nfpr:::::::::%s:\n' "$1" > "$MOCK_KEYS_FILE"
}

configure_accounts() {
  jq -c -f "$REPO_DIR/test/persona/accounts.jq" "$MOCK_BUNDLE_FILE" > "$BATS_TEST_TMPDIR/accounts.json"
  cp "$BATS_TEST_TMPDIR/accounts.json" "$MOCK_BUNDLE_FILE"
}

# Preserve separate output streams: activation stdout must contain shell code only.
shimmer() {
  SHIMMER_CALLER_PWD="${SHIMMER_CALLER_PWD:-$PWD}" \
    mise -C "$REPO_DIR" run -q "$@"
}
export -f shimmer

# Perl is already required by shasum. A new session makes nonterminal consent
# tests deterministic even when the BATS runner itself has a controlling tty.
without_terminal() {
  perl -MPOSIX -e '
    defined(POSIX::setsid()) or die "cannot detach test terminal\n";
    exec @ARGV;
    die "cannot execute test command\n";
  ' -- "$@"
}

activate() {
  # Arguments expand in the child shell, not in this launcher.
  # shellcheck disable=SC2016
  without_terminal bash -c '
    source "$1/lib/persona/activate.sh"
    persona_activate alice "$2"
  ' _ "$REPO_DIR" "${1:-}" > "$STDOUT" 2> "$STDERR"
}

apply_activation() {
  activate
  # shellcheck source=/dev/null
  source "$STDOUT"
}

approval() {
  awk '/Retry with/ {print $(NF-4)}' "$STDERR"
}
