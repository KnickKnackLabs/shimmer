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
  echo "$output" | grep -q "converted 1 codeblock"

  # Should now be a callout (promoted to warning since junior spoke last)
  grep -q '> \[!warning\]-\|> \[!note\]-' "$HUMAN_PATH"
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
  echo "$output" | grep -q "Nothing to tidy"

  # Codeblock should be untouched
  grep -q '```' "$HUMAN_PATH"
}

@test "tidy: nothing to tidy when all types are correct" {
  # warning where Or should respond, note where agent should respond
  local correct_warning='> [!warning]- Waiting on Or 👈
> **[Or]** Question.
>
> ---
>
> **[junior]** My response.'
  write_threads "$correct_warning" "$THREAD_AGENT_WAITING"
  run run_task tidy
  echo "$output" | grep -q "Nothing to tidy"
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
  echo "$output" | grep -q "converted 2 codeblocks"
}

# ============ Promote/demote ============

@test "tidy: promotes note to warning when waiting on Or" {
  write_threads "$THREAD_OR_WAITING"
  run run_task tidy
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "promoted 1 to warning"
  grep -q '\[!warning\]-' "$HUMAN_PATH"
}

@test "tidy: adds pointing hand when promoting to warning" {
  write_threads "$THREAD_OR_WAITING"
  run_task tidy
  grep '\[!warning\]' "$HUMAN_PATH" | grep -q '👈'
}

@test "tidy: demotes warning to note when waiting on agent" {
  local warning_agent='> [!warning]- Agent should act 👈
> **[Or]** Please do something.'
  write_threads "$warning_agent"
  run run_task tidy
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "demoted 1 to note"
  grep -q '\[!note\]-' "$HUMAN_PATH"
}

@test "tidy: removes pointing hand when demoting from warning" {
  local warning_agent='> [!warning]- Agent should act 👈
> **[Or]** Please do something.'
  write_threads "$warning_agent"
  run_task tidy
  ! grep -q '👈' "$HUMAN_PATH"
}

@test "tidy: does not touch success threads" {
  write_threads "$THREAD_SUCCESS"
  run run_task tidy
  echo "$output" | grep -q "Nothing to tidy"
  grep -q '\[!success\]-' "$HUMAN_PATH"
}

@test "tidy: promote and demote in same run" {
  local warning_agent='> [!warning]- Agent should act 👈
> **[Or]** Please do something.'
  write_threads "$THREAD_OR_WAITING" "$warning_agent"
  run run_task tidy
  echo "$output" | grep -q "promoted 1"
  echo "$output" | grep -q "demoted 1"
}

@test "tidy: idempotent after promote/demote" {
  write_threads "$THREAD_OR_WAITING"
  run_task tidy
  run run_task tidy
  echo "$output" | grep -q "Nothing to tidy"
}
