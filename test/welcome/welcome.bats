#!/usr/bin/env bats

setup() {
  load helpers
}

@test "email: not configured when no himalaya config" {
  export AGENT="test-agent"
  export HIMALAYA_CONFIG="$BATS_TEST_TMPDIR/nonexistent.toml"

  run check_email
  [[ "$output" == *"✗"* ]]
  [[ "$output" == *"not configured"* ]]
}

@test "email: timed out after 5s when server unreachable" {
  setup_email
  _task() { return 124; }
  export -f _task

  run check_email
  [[ "$output" == *"✗"* ]]
  [[ "$output" == *"timed out after 5s"* ]]
}

@test "email: success with unread and low quota" {
  setup_email
  _task() {
    if [ "$1" = "--timeout" ]; then shift 2; fi
    case "$1" in
      email:quota) echo "Usage: 42%" ;;
      email:list) echo "5" ;;
    esac
  }
  export -f _task

  run check_email
  [[ "$output" == *"✓"* ]]
  [[ "$output" == *"5 unread"* ]]
  [[ "$output" == *"quota 42%"* ]]
}

@test "email: success with zero unread" {
  setup_email
  _task() {
    if [ "$1" = "--timeout" ]; then shift 2; fi
    case "$1" in
      email:quota) echo "Usage: 10%" ;;
      email:list) echo "0" ;;
    esac
  }
  export -f _task

  run check_email
  [[ "$output" == *"✓"* ]]
  [[ "$output" == *"0 unread"* ]]
}

@test "email: warning when quota >= 80%" {
  setup_email
  _task() {
    if [ "$1" = "--timeout" ]; then shift 2; fi
    case "$1" in
      email:quota) echo "Usage: 85%" ;;
      email:list) echo "2" ;;
    esac
  }
  export -f _task

  run check_email
  [[ "$output" == *"⚠"* ]]
  [[ "$output" == *"2 unread"* ]]
  [[ "$output" == *"quota 85%"* ]]
}

@test "email: critical when quota >= 95%" {
  setup_email
  _task() {
    if [ "$1" = "--timeout" ]; then shift 2; fi
    case "$1" in
      email:quota) echo "Usage: 97%" ;;
      email:list) echo "12" ;;
    esac
  }
  export -f _task

  run check_email
  [[ "$output" == *"✗"* ]]
  [[ "$output" == *"12 unread"* ]]
  [[ "$output" == *"quota 97%"* ]]
  [[ "$output" == *"email:purge"* ]]
}
