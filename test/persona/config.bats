#!/usr/bin/env bats
load ../as/helpers

reject_changes() {
  local change
  cp "$MOCK_BUNDLE_FILE" "$BATS_TEST_TMPDIR/original.json"
  for change in "$@"; do
    jq -c "$change" "$BATS_TEST_TMPDIR/original.json" > "$MOCK_BUNDLE_FILE"
    ! activate
    [ ! -s "$STDOUT" ]
    [ "$(< "$STDERR")" = 'ERROR: incomplete or invalid persona configuration.' ]
  done
}

@test "Git name, email and full signing fingerprint are all mandatory" {
  reject_changes \
    'del(."alice/git/name")' \
    '."alice/git/email" = ""' \
    '."alice/git/signing_fingerprint" = "AAAAAAAA"' \
    '."alice/git/name" = "embedded\u0000nul"'
}

@test "declared accounts require complete fields and a declared default" {
  configure_accounts
  reject_changes \
    'del(."alice/email/personal/smtp/password")' \
    'del(."alice/email/shared/signing_fingerprint")' \
    'del(."alice/blobs/shared/application_key")' \
    '."alice/email/default_account" = "missing"' \
    'del(."alice/blobs/default_account")'
}

@test "account labels must be unique and safe for uppercase environment names" {
  configure_accounts
  reject_changes \
    '."alice/email/accounts" = "personal personal"' \
    '."alice/blobs/accounts" = "invalid-label"' \
    '."alice/email/accounts" = "PERSONAL"'
}

@test "email transport ports must be in the range 1 through 65535" {
  configure_accounts
  reject_changes \
    '."alice/email/shared/imap/port" = "65536"' \
    '."alice/email/personal/smtp/port" = "0"'
}

@test "email transport requires explicit tls or starttls encryption" {
  configure_accounts
  reject_changes '."alice/email/personal/smtp/encryption" = "none"'
}

@test "blob accounts currently support only the b2 provider" {
  configure_accounts
  reject_changes '."alice/blobs/personal/provider" = "s3"'
}

@test "every configured email signer is checked, not only Git or the default account" {
  configure_accounts
  jq -c '."alice/email/personal/signing_fingerprint" = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"' \
    "$MOCK_BUNDLE_FILE" > "$BATS_TEST_TMPDIR/changed.json"
  cp "$BATS_TEST_TMPDIR/changed.json" "$MOCK_BUNDLE_FILE"
  ! activate
  [ ! -s "$STDOUT" ]
  [ "$(< "$STDERR")" = 'ERROR: a configured signer lacks a valid signing-capable secret key.' ]
}

@test "unconfigured capabilities and unknown vault fields do not create exports" {
  jq -c '. + {"alice/email/accounts":"", "alice/blobs/unlisted/password":"not-exported"}' \
    "$MOCK_BUNDLE_FILE" > "$BATS_TEST_TMPDIR/changed.json"
  cp "$BATS_TEST_TMPDIR/changed.json" "$MOCK_BUNDLE_FILE"
  apply_activation
  [ "${EMAIL_ACCOUNTS+x}" != x ]
  [ "${BLOBS_ACCOUNTS+x}" != x ]
  [[ "$(< "$STDOUT")" != *not-exported* ]]
}
