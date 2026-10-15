#!/usr/bin/env bats
# Account/global Git defaults never substitute for the vault's exact signer.
load helpers

# GnuPG colon records use these fields for validity, expiry, signing capability,
# and secret-key availability. '+' is present; '#' is an unavailable secret.
key_record() {
  local kind="$1" validity="$2" expiry="$3"
  local capabilities="$4" secret="$5" fingerprint="$6"

  printf '%s:%s:2048:1:123:1:%s:::::%s:::%s:\nfpr:::::::::%s:\n' \
    "$kind" "$validity" "$expiry" "$capabilities" "$secret" "$fingerprint"
}

@test "exact secret signer rejects unusable keys without emitting commands" {
  local scenario validity expiry capabilities secret
  while IFS='|' read -r scenario validity expiry capabilities secret; do
    printf '# signer case: %s\n' "$scenario" >&3
    key_record sec "$validity" "$expiry" "$capabilities" "$secret" \
      AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA > "$MOCK_KEYS_FILE"

    ! activate

    [ ! -s "$STDOUT" ]
    [[ "$(< "$STDERR")" == *'valid signing-capable secret key'* ]]
  done <<'CASES'
revoked|r|0|scSC|+
expired validity|e|0|scSC|+
disabled validity|d|0|scSC|+
invalid validity|i|0|scSC|+
past expiry|u|1|scSC|+
aggregate signing capability only|u|0|cSC|+
unavailable secret|u|0|scSC|#
CASES
}

@test "GnuPG disabled primary capability rejects a primary signer" {
  key_record sec u 0 scSCD '+' \
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA > "$MOCK_KEYS_FILE"

  ! activate

  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'valid signing-capable secret key'* ]]
}

@test "GnuPG disabled primary capability also rejects its signing subkey" {
  key_record sec u 0 cSCD '+' \
    BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB > "$MOCK_KEYS_FILE"
  key_record ssb u 0 s '+' \
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA >> "$MOCK_KEYS_FILE"

  ! activate

  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'valid signing-capable secret key'* ]]
}

@test "valid signing subkey matches its own exact fingerprint" {
  key_record sec u 0 cSC '#' \
    BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB > "$MOCK_KEYS_FILE"
  key_record ssb u 0 s '+' \
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA >> "$MOCK_KEYS_FILE"

  apply_activation

  [ "$GIT_CONFIG_VALUE_2" = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA ]
}

@test "signing subkey cannot make its certify-only primary a signer" {
  key_record sec u 0 cSC '#' \
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA > "$MOCK_KEYS_FILE"
  key_record ssb u 0 s '+' \
    BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB >> "$MOCK_KEYS_FILE"

  ! activate

  [ ! -s "$STDOUT" ]
  [[ "$(< "$STDERR")" == *'valid signing-capable secret key'* ]]
}

@test "revoked or expired primary invalidates an otherwise valid signing subkey" {
  local validity
  for validity in r e; do
    key_record sec "$validity" 0 cSC '+' \
      BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB > "$MOCK_KEYS_FILE"
    key_record ssb u 0 s '+' \
      AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA >> "$MOCK_KEYS_FILE"

    ! activate

    [ ! -s "$STDOUT" ]
    [[ "$(< "$STDERR")" == *'valid signing-capable secret key'* ]]
  done
}

@test "key listing failure stops before emitting commands without exposing GnuPG diagnostics" {
  export MOCK_GPG_STATUS=1

  ! activate

  [ ! -s "$STDOUT" ]
  [ "$(< "$STDERR")" = 'ERROR: could not inspect secret signing keys.' ]
}

@test "signer inspection requests metadata only and never falls back to global Git defaults" {
  apply_activation
  local metadata_flags='--batch --no-tty --with-colons'
  metadata_flags+=' --with-fingerprint --with-subkey-fingerprint --list-secret-keys'
  grep -Fx -- "$metadata_flags" "$MOCK_CALLS"

  key BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB

  ! activate

  [ ! -s "$STDOUT" ]
}
