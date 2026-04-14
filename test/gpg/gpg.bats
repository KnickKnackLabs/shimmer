#!/usr/bin/env bats
# Tests for lib/gpg.sh helpers and gpg:setup task

load helpers.bash

setup() {
  source "$SHIMMER_DIR/lib/gpg.sh"
  generate_test_gpg_key
}

teardown() {
  cleanup_test_gpg
}

# --- strip_wrapping_quotes ---

@test "strip_wrapping_quotes: removes wrapping double quotes" {
  result=$(strip_wrapping_quotes '"hello world"')
  [ "$result" = "hello world" ]
}

@test "strip_wrapping_quotes: leaves unquoted strings unchanged" {
  result=$(strip_wrapping_quotes 'hello world')
  [ "$result" = "hello world" ]
}

@test "strip_wrapping_quotes: leaves strings with only leading quote unchanged" {
  result=$(strip_wrapping_quotes '"hello world')
  [ "$result" = '"hello world' ]
}

@test "strip_wrapping_quotes: leaves strings with only trailing quote unchanged" {
  result=$(strip_wrapping_quotes 'hello world"')
  [ "$result" = 'hello world"' ]
}

@test "strip_wrapping_quotes: handles empty string" {
  result=$(strip_wrapping_quotes '')
  [ "$result" = "" ]
}

@test "strip_wrapping_quotes: preserves internal quotes" {
  result=$(strip_wrapping_quotes '"hello "world" bye"')
  [ "$result" = 'hello "world" bye' ]
}

@test "strip_wrapping_quotes: handles multiline PGP key with quotes" {
  quoted_key=$(quote_wrap "$VALID_GPG_KEY")
  result=$(strip_wrapping_quotes "$quoted_key")
  # First line should be the armor header, not a quote
  first_line=$(echo "$result" | head -1)
  [ "$first_line" = "-----BEGIN PGP PRIVATE KEY BLOCK-----" ]
}

# --- validate_gpg_key ---

@test "validate_gpg_key: accepts a valid GPG private key" {
  run validate_gpg_key "$VALID_GPG_KEY"
  [ "$status" -eq 0 ]
}

@test "validate_gpg_key: rejects empty input" {
  run validate_gpg_key ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"empty"* ]]
}

@test "validate_gpg_key: rejects key wrapped in quotes" {
  quoted_key=$(quote_wrap "$VALID_GPG_KEY")
  run validate_gpg_key "$quoted_key"
  [ "$status" -eq 1 ]
  [[ "$output" == *"starts with a double quote"* ]]
}

@test "validate_gpg_key: rejects garbage data" {
  run validate_gpg_key "not a gpg key at all"
  [ "$status" -eq 1 ]
  [[ "$output" == *"doesn't start with PGP armor header"* ]]
}

@test "validate_gpg_key: rejects truncated key with valid header" {
  truncated="-----BEGIN PGP PRIVATE KEY BLOCK-----

mQENBF
-----END PGP PRIVATE KEY BLOCK-----"
  run validate_gpg_key "$truncated"
  [ "$status" -eq 1 ]
  [[ "$output" == *"GPG cannot parse key"* ]]
}

# --- gpg:setup integration ---

@test "gpg:setup: imports a valid key from env" {
  mock_shimmer

  export GPG_PRIVATE_KEY="$VALID_GPG_KEY"
  run shimmer gpg:setup test
  [ "$status" -eq 0 ]
  [[ "$output" == *"GPG configured for test@ricon.family"* ]]
}

@test "gpg:setup: imports a quoted key from env (auto-strips quotes)" {
  mock_shimmer

  export GPG_PRIVATE_KEY=$(quote_wrap "$VALID_GPG_KEY")
  run shimmer gpg:setup test
  [ "$status" -eq 0 ]
  [[ "$output" == *"GPG configured for test@ricon.family"* ]]
}

@test "gpg:setup: rejects garbage key with helpful error" {
  mock_shimmer

  # Must be >100 chars to pass length check and reach validation
  export GPG_PRIVATE_KEY=$(python3 -c "print('x' * 200)")
  run shimmer gpg:setup test
  [ "$status" -ne 0 ]
  [[ "$output" == *"doesn't start with PGP armor header"* ]]
}
