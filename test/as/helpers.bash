# Helpers for shimmer `as` BATS tests
#
# Suite-specific: setup_test_home with agent:list, agent:identity, and identity files.
# Shared helpers (mock_task, mock_shimmer, shimmer wrapper) loaded from test/helpers.bash.

# shellcheck source=test/helpers.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.bash"

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

  # agent:identity — returns content, not path
  cat > "$TEST_HOME/.mise/tasks/agent/identity" <<'TASK'
#!/usr/bin/env bash
#MISE description="Output identity content"
AGENT="$1"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
IDENTITY_FILE="$DIR/notes/$AGENT.md"
if [ -f "$IDENTITY_FILE" ]; then
  cat "$IDENTITY_FILE"
else
  echo "Error: no identity for $AGENT" >&2
  exit 1
fi
TASK
  chmod +x "$TEST_HOME/.mise/tasks/agent/identity"

  TEST_AGENTS_ROOT="$BATS_TEST_TMPDIR/agents-root-$$"
  export TEST_AGENTS_ROOT
  export SHIMMER_AGENTS_ROOT="$TEST_AGENTS_ROOT"

  # Identity files + private agent homes with signing config.
  for agent in "${agents[@]}"; do
    cat > "$TEST_HOME/notes/$agent.md" <<EOF
---
title: $agent
tags: [agent, identity]
---

# $agent
You are $agent.
EOF

    mkdir -p "$TEST_AGENTS_ROOT/$agent/home"
    git -C "$TEST_AGENTS_ROOT/$agent/home" init -q -b main
    git -C "$TEST_AGENTS_ROOT/$agent/home" config user.name "$agent"
    git -C "$TEST_AGENTS_ROOT/$agent/home" config user.email "$agent@ricon.family"
    git -C "$TEST_AGENTS_ROOT/$agent/home" config user.signingkey "TESTKEY-$agent"
    git -C "$TEST_AGENTS_ROOT/$agent/home" config commit.gpgsign true
    git -C "$TEST_AGENTS_ROOT/$agent/home" config tag.gpgsign true
  done

  # Git init
  git -C "$TEST_HOME" init -q -b main
  git -C "$TEST_HOME" config user.email "test@test.com"
  git -C "$TEST_HOME" config user.name "Test"

  export TEST_HOME
}
