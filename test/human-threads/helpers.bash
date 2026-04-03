# Helpers for human:threads BATS tests
#
# Suite-specific: test isolation via temporary directories with a mock
# home repo that has a `human` task returning the HUMAN.md path.
# Shared helpers (SHIMMER_DIR, mock infrastructure) loaded from test/helpers.bash.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)/helpers.bash"

# Create an isolated test environment with a mock home repo
# Sets: TEST_HOME, HUMAN_PATH, ARCHIVE_PATH
setup_test_home() {
  TEST_HOME="$BATS_TEST_TMPDIR/human-test-$$"
  mkdir -p "$TEST_HOME/.mise/tasks"

  # Create mock `human` task that returns the HUMAN.md path
  cat > "$TEST_HOME/.mise/tasks/human" <<'TASK'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo "$DIR/HUMAN.md"
TASK
  chmod +x "$TEST_HOME/.mise/tasks/human"

  # Initialize git repo (mise needs this)
  git -C "$TEST_HOME" init -q -b main
  git -C "$TEST_HOME" config user.email "test@test.com"
  git -C "$TEST_HOME" config user.name "Test"

  HUMAN_PATH="$TEST_HOME/HUMAN.md"
  ARCHIVE_PATH="$TEST_HOME/HUMAN.archive.md"

  export TEST_HOME HUMAN_PATH ARCHIVE_PATH
}

# Run a shimmer human:threads task against the test home
# Usage: run_task <task_name> [args...]
run_task() {
  local task="$1"
  shift
  CALLER_PWD="$TEST_HOME" mise -C "$SHIMMER_DIR" run -q "human:threads:$task" "$@"
}

# Write a minimal HUMAN.md with header and given body content
# Usage: write_human_md "body content"
write_human_md() {
  local body="${1:-}"
  cat > "$HUMAN_PATH" <<EOF
# HUMAN

Test scratchpad.

--- HEADER END ---
${body}
EOF
}

# Write a HUMAN.md with specific threads
# Usage: write_threads [thread_blocks...]
# Each argument is a complete callout block (including "> " prefix)
write_threads() {
  local body=""
  for thread in "$@"; do
    body="${body}
${thread}
"
  done
  write_human_md "$body"
}

# Standard thread fixtures
THREAD_NOTE='> [!note]- Test thread (Mar 15)
> **[Or]** This is a test note.
>
> ---
>
> **[junior]** Noted.'

THREAD_WARNING='> [!warning]- Urgent thing 👈
> **[Or]** This needs attention.'

THREAD_SUCCESS='> [!success]- Done thing (resolved Mar 15)
> Completed successfully.'

THREAD_AGENT_WAITING='> [!note]- Agent should respond
> **[Or]** What do you think?'

THREAD_OR_WAITING='> [!note]- Or should respond
> **[Or]** Starting thought.
>
> ---
>
> **[junior]** Here is my response.'

THREAD_NO_AUTHORS='> [!note]- Empty thread
> No author markers here.'

# Thread with arrow chain authorship convention
THREAD_ARROW_CHAIN='> [!note]- Rewritten thread (Mar 15)
> **[Or → x1f9]** This message was clarified by x1f9.
>
> ---
>
> **[junior]** Looks good to me.'

# Thread with multi-hop arrow chain
THREAD_MULTI_ARROW='> [!note]- Multi-edit thread
> **[Or → x1f9 → brownie]** Edited twice.'

# Thread where Or's message was rewritten by an agent (arrow notation)
# The bug: tidy saw "Zeke" as last author and promoted to warning,
# but Or sent this message — it should stay as note (waiting on agent).
THREAD_OR_REWRITTEN_BY_AGENT='> [!note]- Or said something, agent rewrote
> **[Or → Zeke]** This is Or speaking, Zeke just cleaned up the prose.
>
> ---
>
> **[Zeke]** My actual response to Or.'

# Thread where agent's rewrite is the last message (should wait on agent)
THREAD_OR_REWRITTEN_LAST='> [!note]- Or spoke last via rewrite
> **[Zeke]** I said something first.
>
> ---
>
> **[Or → Zeke]** Or replied, Zeke cleaned it up.'

# Thread with multi-paragraph content (blank lines inside callout)
THREAD_MULTI_PARAGRAPH='> [!note]- Long discussion (Mar 15)
> **[Or]** First paragraph of thought.
>
> Second paragraph continues here.
>
> Third paragraph with more detail.
>
> ---
>
> **[junior]** My multi-paragraph reply.
>
> Continued thoughts here.'

# Two adjacent threads separated by a blank line
THREAD_ADJACENT_A='> [!note]- Thread A
> **[Or]** Content A.'

THREAD_ADJACENT_B='> [!note]- Thread B
> **[junior]** Content B.'

# A raw codeblock that tidy should convert
RAW_CODEBLOCK='```
[Or] Hey, what do you think about this?

[junior] I think it looks good.
```'
