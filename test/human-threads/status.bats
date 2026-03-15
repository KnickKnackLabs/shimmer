#!/usr/bin/env bats

setup() {
  load helpers
  setup_test_home
}

teardown() {
  rm -rf "$TEST_HOME"
}

# ============ Basic counts ============

@test "status: counts threads correctly" {
  write_threads "$THREAD_NOTE" "$THREAD_WARNING" "$THREAD_SUCCESS"
  run run_task status
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "3 threads"
}

@test "status: identifies waiting on agent" {
  write_threads "$THREAD_AGENT_WAITING"
  run run_task status
  echo "$output" | grep -q "1 waiting on agent"
}

@test "status: identifies waiting on Or" {
  write_threads "$THREAD_OR_WAITING"
  run run_task status
  echo "$output" | grep -q "1 waiting on Or"
}

@test "status: identifies resolved" {
  write_threads "$THREAD_SUCCESS"
  run run_task status
  echo "$output" | grep -q "1 resolved"
}

@test "status: mixed thread types" {
  write_threads "$THREAD_AGENT_WAITING" "$THREAD_OR_WAITING" "$THREAD_SUCCESS"
  run run_task status
  echo "$output" | grep -q "3 threads"
  echo "$output" | grep -q "1 waiting on agent"
  echo "$output" | grep -q "1 waiting on Or"
  echo "$output" | grep -q "1 resolved"
}

# ============ Edge cases ============

@test "status: no threads" {
  write_human_md ""
  run run_task status
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "0 threads"
}

@test "status: thread with no authors" {
  write_threads "$THREAD_NO_AUTHORS"
  run run_task status
  echo "$output" | grep -q "1 no messages"
}

@test "status: fails when HUMAN.md missing" {
  run run_task status
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "No HUMAN.md found"
}
