# Shared helpers for shimmer as BATS tests
#
# Uses the "mock-first include overlay" pattern: an empty mise project
# whose task_config includes mock tasks before shimmer's real tasks.
# First include wins, so mocks override without copying anything.

SHIMMER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Create a test home with agent:list, agent:identity, and identity files.
# Does NOT create an overlay — tests build their own with mock_shimmer.
# Usage: setup_test_home [agent_names...]
setup_test_home() {
  TEST_HOME="$BATS_TEST_TMPDIR/home-$$"
  mkdir -p "$TEST_HOME/.mise/tasks/agent"
  mkdir -p "$TEST_HOME/notes"

  local agents=("$@")
  [ ${#agents[@]} -eq 0 ] && agents=("alice" "bob")

  # agent:list
  cat > "$TEST_HOME/.mise/tasks/agent/list" <<TASK
#!/usr/bin/env bash
#MISE description="List agents"
$(printf 'echo "%s"\n' "${agents[@]}")
TASK
  chmod +x "$TEST_HOME/.mise/tasks/agent/list"

  # agent:identity
  cat > "$TEST_HOME/.mise/tasks/agent/identity" <<'TASK'
#!/usr/bin/env bash
#MISE description="Resolve identity"
AGENT="$1"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
IDENTITY_FILE="$DIR/notes/$AGENT.md"
if [ -f "$IDENTITY_FILE" ]; then
  echo "$IDENTITY_FILE"
else
  echo "Error: no identity for $AGENT" >&2
  exit 1
fi
TASK
  chmod +x "$TEST_HOME/.mise/tasks/agent/identity"

  # Identity files
  for agent in "${agents[@]}"; do
    cat > "$TEST_HOME/notes/$agent.md" <<EOF
---
title: $agent
tags: [agent, identity]
---

# $agent
You are $agent.
EOF
  done

  # Git init
  git -C "$TEST_HOME" init -q -b main
  git -C "$TEST_HOME" config user.email "test@test.com"
  git -C "$TEST_HOME" config user.name "Test"

  export TEST_HOME
}

# Create a mock task file. Call this before mock_shimmer.
# Usage: mock_task "secret/get" "echo fake_token"
mock_task() {
  local task_path="$1" body="$2"
  local mock_dir="$BATS_TEST_TMPDIR/mocks-$$"
  mkdir -p "$mock_dir/$(dirname "$task_path")"
  cat > "$mock_dir/$task_path" <<EOF
#!/usr/bin/env bash
$body
EOF
  chmod +x "$mock_dir/$task_path"
}

# Build an overlay that includes: test home tasks, mocks (if any), then shimmer.
# Must be called after setup_test_home and any mock_task calls.
# Usage: mock_shimmer
mock_shimmer() {
  local mock_dir="$BATS_TEST_TMPDIR/mocks-$$"
  OVERLAY="$BATS_TEST_TMPDIR/overlay-$$"
  mkdir -p "$OVERLAY"

  # Build includes list: home tasks first, then mocks (if any), then shimmer
  local includes="\"$TEST_HOME/.mise/tasks\""
  if [ -d "$mock_dir" ]; then
    includes="$includes, \"$mock_dir\""
  fi
  includes="$includes, \"$SHIMMER_DIR/.mise/tasks\""

  cat > "$OVERLAY/mise.toml" <<EOF
[task_config]
includes = [$includes]
EOF
  git -C "$OVERLAY" init -q -b main
  git -C "$OVERLAY" config user.email "test@test.com"
  git -C "$OVERLAY" config user.name "Test"
  mise trust "$OVERLAY/mise.toml" 2>/dev/null

  export OVERLAY
}

# Run shimmer as via the overlay
run_as() {
  CALLER_PWD="$TEST_HOME" mise -C "$OVERLAY" run -q as "$@" 2>&1
}
