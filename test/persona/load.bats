#!/usr/bin/env bats
# Internal loader tests only: no public `as` routing or real vault access.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  source "$REPO_DIR/lib/persona.sh"
  export MOCK_BUNDLE='{"alice/git/name":"Alice","alice/github/token":"synthetic-token"}'
  export MOCK_SECRETS_STATUS=0
  export MOCK_CALLS="$BATS_TEST_TMPDIR/secrets-calls"
  export MOCK_PROVIDER="$BATS_TEST_TMPDIR/provider"

  secrets() {
    printf '%s\n' "$*" >> "$MOCK_CALLS"
    printf '%s' "${SECRETS_PROVIDER:-}" > "$MOCK_PROVIDER"
    printf '%s' "$MOCK_BUNDLE"
    printf 'synthetic-provider-diagnostic\n' >&2
    return "$MOCK_SECRETS_STATUS"
  }
}

@test "loader captures provider JSON without emitting exports or changing the persona" {
  export AGENT_HOME=/existing/home GH_TOKEN=existing-token
  persona_load alice > "$BATS_TEST_TMPDIR/stdout"
  [ ! -s "$BATS_TEST_TMPDIR/stdout" ]
  [ "$AGENT_HOME" = /existing/home ]
  [ "$GH_TOKEN" = existing-token ]
  [ "$(printf '%s' "$PERSONA_DATA" | jq -r '."git/name"')" = Alice ]
  [ "$(printf '%s' "$PERSONA_DATA" | jq -r '."github/token"')" = synthetic-token ]
  [ "$(paste -sd ' ' "$MOCK_CALLS")" = 'export --prefix alice/' ]
  run bash -c 'test "${PERSONA_DATA+x}" != x'
  [ "$status" -eq 0 ]
}

@test "loader preserves the caller's provider selection" {
  local provider
  for provider in sops 1password; do
    export SECRETS_PROVIDER="$provider"

    persona_load alice

    [ "$(< "$MOCK_PROVIDER")" = "$provider" ]
    [ "$SECRETS_PROVIDER" = "$provider" ]
  done
  [ "$(grep -c '^export --prefix alice/$' "$MOCK_CALLS")" -eq 2 ]
}

@test "loader retains email and blobs but drops unrelated secrets" {
  MOCK_BUNDLE='{"alice/email/accounts":"personal","alice/blobs/accounts":"shared","alice/gpg-private-key":"synthetic-private-key"}'
  persona_load alice
  [ "$(printf '%s' "$PERSONA_DATA" | jq -r 'keys | join(" ")')" = 'blobs/accounts email/accounts' ]
}

@test "loader preserves encoded multiline credentials without evaluating their content" {
  MOCK_BUNDLE='{"alice/email/personal/imap/password":"line one\n$(false)\n"}'
  persona_load alice
  [ "$PERSONA_DATA" = '{"email/personal/imap/password":"line one\n$(false)\n"}' ]
}

@test "loader leaves missing optional capabilities for later schema validation" {
  MOCK_BUNDLE='{"alice/git/name":"Alice"}'
  persona_load alice
  [ "$PERSONA_DATA" = '{"git/name":"Alice"}' ]
}

@test "provider failure emits no data and preserves previous working state" {
  PERSONA_DATA=previous
  MOCK_SECRETS_STATUS=1
  if persona_load alice > "$BATS_TEST_TMPDIR/stdout" 2> "$BATS_TEST_TMPDIR/stderr"; then
    return 1
  fi
  [ "$PERSONA_DATA" = previous ]
  [ ! -s "$BATS_TEST_TMPDIR/stdout" ]
  [ "$(< "$BATS_TEST_TMPDIR/stderr")" = 'ERROR: could not load persona from the selected Secrets provider.' ]
  [ "$(wc -l < "$MOCK_CALLS" | tr -d ' ')" = 1 ]
}

@test "loader rejects malformed bundles without leaking their contents" {
  local invalid
  for invalid in 'synthetic-secret' '[]' '{} {}' '{"bob/git/name":"synthetic-secret"}' '{"alice/git/name":null}'; do
    MOCK_BUNDLE="$invalid"
    PERSONA_DATA=previous
    if persona_load alice > "$BATS_TEST_TMPDIR/stdout" 2> "$BATS_TEST_TMPDIR/stderr"; then
      return 1
    fi
    [ "$PERSONA_DATA" = previous ]
    [ ! -s "$BATS_TEST_TMPDIR/stdout" ]
    [ "$(< "$BATS_TEST_TMPDIR/stderr")" = 'ERROR: Secrets returned an invalid persona bundle.' ]
  done
}

@test "loader rejects empty or multi-segment handles before requesting secrets" {
  run persona_load ''
  [ "$status" -ne 0 ]
  run persona_load alice/git
  [ "$status" -ne 0 ]
  [ ! -e "$MOCK_CALLS" ]
}

@test "loader suppresses shell tracing of synthetic credentials" {
  run bash -c '
    source "$1/lib/persona.sh"
    secrets() { printf "%s" "$MOCK_BUNDLE"; }
    set -x
    persona_load alice
  ' _ "$REPO_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *synthetic-token* ]]
}
