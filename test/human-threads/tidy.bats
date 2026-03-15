#!/usr/bin/env bats

setup() {
  load helpers
  setup_test_home
}

teardown() {
  rm -rf "$TEST_HOME"
}

# ============ Conversion ============

@test "tidy: converts raw codeblock to callout" {
  write_human_md "
$RAW_CODEBLOCK
"
  run run_task tidy
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Converted 1 codeblock"

  # Should now be a callout
  grep -q '> \[!note\]-' "$HUMAN_PATH"
  # Should have bolded names
  grep -q '\*\*\[Or\]\*\*' "$HUMAN_PATH"
  grep -q '\*\*\[junior\]\*\*' "$HUMAN_PATH"
}

@test "tidy: adds dividers between messages" {
  write_human_md "
$RAW_CODEBLOCK
"
  run_task tidy
  grep -q '> ---' "$HUMAN_PATH"
}

@test "tidy: adds TODO title" {
  write_human_md "
$RAW_CODEBLOCK
"
  run_task tidy
  grep -q 'TODO: title this thread' "$HUMAN_PATH"
}

# ============ Selective conversion ============

@test "tidy: ignores codeblocks without [Name] patterns" {
  write_human_md '
```
echo "hello world"
ls -la
```
'
  run run_task tidy
  echo "$output" | grep -q "No raw codeblocks to convert"

  # Codeblock should be untouched
  grep -q '```' "$HUMAN_PATH"
}

@test "tidy: no codeblocks reports nothing to convert" {
  write_threads "$THREAD_NOTE"
  run run_task tidy
  echo "$output" | grep -q "No raw codeblocks to convert"
}

# ============ Multiple codeblocks ============

@test "tidy: converts multiple codeblocks" {
  write_human_md '
```
[Or] First thought.
```

```
[junior] Second thought.
```
'
  run run_task tidy
  echo "$output" | grep -q "Converted 2 codeblocks"
}
