#!/usr/bin/env bats

setup() {
  load helpers
  setup_test_home
}

teardown() {
  rm -rf "$TEST_HOME"
}

# ============ Fresh init ============

@test "init: creates HUMAN.md from template" {
  run run_task init
  [ "$status" -eq 0 ]
  [ -f "$HUMAN_PATH" ]
  echo "$output" | grep -q "Initialized HUMAN.md"
}

@test "init: created file contains header marker" {
  run_task init
  grep -Fq -- "--- HEADER END ---" "$HUMAN_PATH"
}

@test "init: created file contains Laurel art" {
  run_task init
  grep -q "Laurel" "$HUMAN_PATH"
}

@test "init: created file contains shimmer task references" {
  run_task init
  grep -q "shimmer human:threads:list" "$HUMAN_PATH"
  grep -q "shimmer human:threads:archive" "$HUMAN_PATH"
}

# ============ Existing file ============

@test "init: refuses when HUMAN.md already exists" {
  write_human_md ""
  run run_task init
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "already exists"
}

@test "init: suggests --force when file exists" {
  write_human_md ""
  run run_task init
  echo "$output" | grep -q "\-\-force"
}

# ============ Force mode ============

@test "init --force: updates header, preserves threads" {
  # Write a HUMAN.md with old header and a thread
  cat > "$HUMAN_PATH" <<'EOF'
# OLD HEADER

--- HEADER END ---

> [!note]- My important thread
> **[Or]** Keep this content.
EOF

  run run_task init -- --force
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Updated header"

  # New header should be present
  grep -q "Laurel" "$HUMAN_PATH"
  grep -q "shimmer human:threads:list" "$HUMAN_PATH"

  # Thread should be preserved
  grep -q "My important thread" "$HUMAN_PATH"
  grep -q "Keep this content" "$HUMAN_PATH"
}

@test "init --force: handles file without header marker" {
  echo "Just some content, no marker." > "$HUMAN_PATH"

  run run_task init -- --force
  [ "$status" -eq 0 ]

  # Should have new header
  grep -Fq -- "--- HEADER END ---" "$HUMAN_PATH"
  # Original content preserved in body
  grep -q "Just some content" "$HUMAN_PATH"
}
