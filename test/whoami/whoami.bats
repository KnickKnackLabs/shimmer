#!/usr/bin/env bats

setup() {
  load helpers
  mock_gh_binary "mock-user"
  mock_shimmer
}

teardown() {
  rm -rf "$OVERLAY" "$MOCK_BIN"
}

@test "whoami: reports the token login when GH_TOKEN is set" {
  export GH_TOKEN="ghp_fake_test_token"

  run shimmer whoami
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Logged in as: mock-user"
}

@test "whoami: falls back to gh auth status when GH_TOKEN is unset" {
  unset GH_TOKEN

  run shimmer whoami
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "GH_TOKEN not set, using:"
  ! echo "$output" | grep -q "unbound variable"
}

@test "whoami: falls back to gh auth status when GH_TOKEN is empty" {
  export GH_TOKEN=""

  run shimmer whoami
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "GH_TOKEN not set, using:"
}
