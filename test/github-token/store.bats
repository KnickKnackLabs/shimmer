#!/usr/bin/env bats

bats_require_minimum_version 1.5.0
load ../helpers

setup() {
  mock_secrets_binary
  export TOKEN_STORE_RECORD="$BATS_TEST_TMPDIR/token-store"
  unset TOKEN_STORE_FAIL

  cat > "$MOCK_BIN/secrets" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[ "$#" -eq 2 ] && [ "$1" = set ] && [ "$2" = demo/github/token ] || exit 2
[ "${TOKEN_STORE_FAIL:-false}" != true ] || exit 1
cat > "$TOKEN_STORE_RECORD"
SH

  mock_shimmer
}

@test "token store writes the persona GitHub field without printing its value" {
  run shimmer github:token:store demo synthetic-token-value

  [ "$status" -eq 0 ]
  [ "$(cat "$TOKEN_STORE_RECORD")" = synthetic-token-value ]
  [[ "$output" == *"Stored PAT for demo"* ]]
  [[ "$output" != *"synthetic-token-value"* ]]
}

@test "token store reports provider failure instead of successful storage" {
  export TOKEN_STORE_FAIL=true

  run shimmer github:token:store demo synthetic-token-value

  [ "$status" -ne 0 ]
  [ ! -e "$TOKEN_STORE_RECORD" ]
  [[ "$output" != *"Stored PAT"* ]]
  [[ "$output" != *"synthetic-token-value"* ]]
}
