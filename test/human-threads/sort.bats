#!/usr/bin/env bats

setup() {
  load helpers
  setup_test_home
}

teardown() {
  rm -rf "$TEST_HOME"
}

# ============ Sort order ============

@test "sort: warning comes first" {
  write_threads "$THREAD_NOTE" "$THREAD_WARNING" "$THREAD_SUCCESS"
  run run_task sort
  [ "$status" -eq 0 ]

  # Warning should appear before note in the file
  local warning_line note_line
  warning_line=$(grep -n "Urgent thing" "$HUMAN_PATH" | head -1 | cut -d: -f1)
  note_line=$(grep -n "Test thread" "$HUMAN_PATH" | head -1 | cut -d: -f1)
  [ "$warning_line" -lt "$note_line" ]
}

@test "sort: success comes last" {
  write_threads "$THREAD_SUCCESS" "$THREAD_NOTE" "$THREAD_WARNING"
  run run_task sort
  [ "$status" -eq 0 ]

  local note_line success_line
  note_line=$(grep -n "Test thread" "$HUMAN_PATH" | head -1 | cut -d: -f1)
  success_line=$(grep -n "Done thing" "$HUMAN_PATH" | head -1 | cut -d: -f1)
  [ "$note_line" -lt "$success_line" ]
}

@test "sort: full order is warning, note, success" {
  write_threads "$THREAD_SUCCESS" "$THREAD_NOTE" "$THREAD_WARNING"
  run run_task sort
  [ "$status" -eq 0 ]

  local warning_line note_line success_line
  warning_line=$(grep -n "Urgent thing" "$HUMAN_PATH" | head -1 | cut -d: -f1)
  note_line=$(grep -n "Test thread" "$HUMAN_PATH" | head -1 | cut -d: -f1)
  success_line=$(grep -n "Done thing" "$HUMAN_PATH" | head -1 | cut -d: -f1)
  [ "$warning_line" -lt "$note_line" ]
  [ "$note_line" -lt "$success_line" ]
}

# ============ Preserves content ============

@test "sort: preserves header" {
  write_threads "$THREAD_NOTE" "$THREAD_WARNING"
  run_task sort
  grep -q "Test scratchpad" "$HUMAN_PATH"
  grep -Fq -- "--- HEADER END ---" "$HUMAN_PATH"
}

@test "sort: preserves thread content" {
  write_threads "$THREAD_NOTE"
  run_task sort
  grep -q "This is a test note" "$HUMAN_PATH"
  grep -q "Noted" "$HUMAN_PATH"
}

# ============ Output ============

@test "sort: reports thread counts" {
  write_threads "$THREAD_NOTE" "$THREAD_WARNING" "$THREAD_SUCCESS"
  run run_task sort
  echo "$output" | grep -q "Sorted 3 threads"
}

@test "sort: no threads reports nothing to sort" {
  write_human_md ""
  run run_task sort
  echo "$output" | grep -q "No threads found"
}

# ============ Idempotent ============

@test "sort: second sort produces identical output" {
  write_threads "$THREAD_WARNING" "$THREAD_NOTE" "$THREAD_SUCCESS"
  # First sort normalizes whitespace
  run_task sort
  cp "$HUMAN_PATH" "$TEST_HOME/after-first.md"
  # Second sort should be a no-op
  run_task sort
  diff -q "$HUMAN_PATH" "$TEST_HOME/after-first.md"
}
