#!/usr/bin/env bats

setup() {
  load helpers
  setup_test_home
}

teardown() {
  rm -rf "$TEST_HOME"
}

# Note: `list` uses gum for table rendering, so we test the underlying
# Python parsing by checking what gum receives (the raw tab-separated output).
# If gum is not available, the task will fail at the gum step — that's OK
# for CI environments without gum. These tests verify the parsing is correct.

# ============ Basic listing ============

@test "list: shows thread titles" {
  write_threads "$THREAD_NOTE" "$THREAD_WARNING"
  run run_task list
  # gum may or may not be available — check output either way
  echo "$output" | grep -q "Test thread"
  echo "$output" | grep -q "Urgent thing"
}

@test "list: shows participants" {
  write_threads "$THREAD_NOTE"
  run run_task list
  echo "$output" | grep -q "junior"
  echo "$output" | grep -q "Or"
}

@test "list: shows waiting-on status" {
  write_threads "$THREAD_AGENT_WAITING"
  run run_task list
  echo "$output" | grep -q "agent"
}

# ============ Empty file ============

@test "list: no threads shows empty message" {
  write_human_md ""
  run run_task list
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "no threads"
}

# ============ Missing file ============

@test "list: fails when HUMAN.md missing" {
  run run_task list
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "No HUMAN.md found"
}
