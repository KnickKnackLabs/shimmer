#!/usr/bin/env bats

setup() {
  load helpers
  setup_test_home
}

teardown() {
  rm -rf "$TEST_HOME"
}

# ============ Basic archiving ============

@test "archive: moves resolved threads to archive file" {
  write_threads "$THREAD_NOTE" "$THREAD_SUCCESS"
  run run_task archive
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Archived 1 resolved thread"

  # Archive file should exist with the resolved thread
  [ -f "$ARCHIVE_PATH" ]
  grep -q "Done thing" "$ARCHIVE_PATH"

  # HUMAN.md should still have the note thread
  grep -q "Test thread" "$HUMAN_PATH"
  # But not the success thread
  ! grep -q "Done thing" "$HUMAN_PATH"
}

@test "archive: creates archive header with Hardy art" {
  write_threads "$THREAD_SUCCESS"
  run_task archive
  grep -q "Hardy" "$ARCHIVE_PATH"
  grep -q "# HUMAN Archive" "$ARCHIVE_PATH"
}

@test "archive: adds date header" {
  write_threads "$THREAD_SUCCESS"
  run_task archive
  local today
  today=$(date +%Y-%m-%d)
  grep -q "## Archived $today" "$ARCHIVE_PATH"
}

# ============ Multiple resolved threads ============

@test "archive: moves all resolved threads" {
  local success2='> [!success]- Another done thing
> Also completed.'

  write_threads "$THREAD_NOTE" "$THREAD_SUCCESS" "$success2"
  run run_task archive
  echo "$output" | grep -q "Archived 2 resolved threads"

  grep -q "Done thing" "$ARCHIVE_PATH"
  grep -q "Another done thing" "$ARCHIVE_PATH"
}

# ============ No resolved threads ============

@test "archive: reports nothing when no resolved threads" {
  write_threads "$THREAD_NOTE" "$THREAD_WARNING"
  run run_task archive
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "No resolved threads to archive"
  [ ! -f "$ARCHIVE_PATH" ]
}

# ============ Preserves content ============

@test "archive: preserves header in HUMAN.md" {
  write_threads "$THREAD_SUCCESS"
  run_task archive
  grep -q "Test scratchpad" "$HUMAN_PATH"
  grep -Fq -- "--- HEADER END ---" "$HUMAN_PATH"
}

@test "archive: preserves active threads in HUMAN.md" {
  write_threads "$THREAD_NOTE" "$THREAD_WARNING" "$THREAD_SUCCESS"
  run_task archive

  grep -q "Test thread" "$HUMAN_PATH"
  grep -q "Urgent thing" "$HUMAN_PATH"
}

# ============ Append to existing archive ============

@test "archive: appends to existing archive file" {
  # First archive
  write_threads "$THREAD_SUCCESS"
  run_task archive

  # Add another resolved thread and archive again
  local success2='> [!success]- Second resolved
> Done again.'
  write_threads "$success2"
  run_task archive

  # Both should be in archive
  grep -q "Done thing" "$ARCHIVE_PATH"
  grep -q "Second resolved" "$ARCHIVE_PATH"

  # Should have two "Archived" date headers
  local count
  count=$(grep -c "## Archived" "$ARCHIVE_PATH")
  [ "$count" -eq 2 ]
}

@test "archive: does not duplicate Hardy header on append" {
  write_threads "$THREAD_SUCCESS"
  run_task archive

  local success2='> [!success]- Another
> Done.'
  write_threads "$success2"
  run_task archive

  local count
  count=$(grep -c "Hardy" "$ARCHIVE_PATH")
  [ "$count" -eq 1 ]
}
