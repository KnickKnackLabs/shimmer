#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load ../helpers
  source "$SHIMMER_DIR/lib/agent-env.sh"
}

@test "agent env: preserves selected-agent auth while scrubbing task-scoped env" {
  export GIT_AUTHOR_NAME="c0da"
  export GIT_AUTHOR_EMAIL="c0da@ricon.family"
  export AGENT_HOME="/tmp/c0da/home"
  export GH_TOKEN="ghp_identity_token"
  export CALLER_PWD="/stale/caller"
  export SHIMMER_CALLER_PWD="/stale/shimmer"
  export OTHER_CALLER_PWD="/stale/other"
  export MISE_CONFIG_ROOT="/stale/shimmer"
  export MISE_ORIGINAL_CWD="/stale/original"
  export MISE_PROJECT_ROOT="/stale/project"
  export MISE_TASK_NAME="agent"
  export MISE_TASK_FILE="/stale/task"
  export usage_headless="true"
  export usage_model="openai-codex/gpt-5.5"

  shimmer_prepare_agent_child_env

  [ "${GIT_AUTHOR_NAME}" = "c0da" ]
  [ "${GIT_AUTHOR_EMAIL}" = "c0da@ricon.family" ]
  [ "${AGENT_HOME}" = "/tmp/c0da/home" ]
  [ "${GH_TOKEN}" = "ghp_identity_token" ]
  [ -z "${CALLER_PWD-}" ]
  [ -z "${SHIMMER_CALLER_PWD-}" ]
  [ -z "${OTHER_CALLER_PWD-}" ]
  [ -z "${MISE_CONFIG_ROOT-}" ] # codebase:ignore mcr-scope — test asserts scrubbed env
  [ -z "${MISE_ORIGINAL_CWD-}" ]
  [ -z "${MISE_PROJECT_ROOT-}" ]
  [ -z "${MISE_TASK_NAME-}" ]
  [ -z "${MISE_TASK_FILE-}" ]
  [ -z "${usage_headless-}" ]
  [ -z "${usage_model-}" ]
}

@test "agent env: accepts paths resolving to authenticated home Git root" {
  export AGENT_HOME="$BATS_TEST_TMPDIR/agent-home"
  local home_link="$BATS_TEST_TMPDIR/agent-home-link"
  mkdir -p "$AGENT_HOME"
  AGENT_HOME=$(cd "$AGENT_HOME" && pwd -P)
  git -C "$AGENT_HOME" init -q -b main
  ln -s "$AGENT_HOME" "$home_link"

  run shimmer_require_agent_home_path "$home_link" "launch directory"

  [ "$status" -eq 0 ]
  [ "$output" = "$AGENT_HOME" ]
}

@test "agent env: rejects a path outside authenticated home" {
  export AGENT_HOME="$BATS_TEST_TMPDIR/agent-home"
  local other="$BATS_TEST_TMPDIR/other"
  mkdir -p "$AGENT_HOME" "$other"
  git -C "$AGENT_HOME" init -q -b main

  run shimmer_require_agent_home_path "$other" "launch directory"

  [ "$status" -ne 0 ]
  [[ "$output" == *"launch directory does not match the authenticated agent home"* ]]
}

@test "agent env: removes direct mise install dirs at runtime boundary" {
  export HOME="$BATS_TEST_TMPDIR/home"
  local data_dir="$HOME/.local/share/mise"
  local installs="$data_dir/installs"
  local old_sessions="$installs/shiv-sessions/0.4.1/bin"
  local new_sessions="$installs/shiv-sessions/0.4.4/bin"
  local threads="$installs/shiv-threads/0.3.0/bin"
  local nested_bats="$installs/bats/1.13.0/bats-core-1.13.0/bin"

  export PATH="/mock/bin:$old_sessions:/custom/bin:$new_sessions:$threads:$nested_bats:/tail/bin:/usr/bin:/bin"

  shimmer_prepare_agent_runtime_path

  [[ ":$PATH:" != *":$old_sessions:"* ]]
  [[ ":$PATH:" != *":$new_sessions:"* ]]
  [[ ":$PATH:" != *":$threads:"* ]]
  [[ ":$PATH:" != *":$nested_bats:"* ]]
  [[ ":$PATH:" == *":/mock/bin:"* ]]
  [[ ":$PATH:" == *":/custom/bin:"* ]]
  [[ ":$PATH:" == *":/tail/bin:"* ]]
  [[ ":$PATH:" == *":$data_dir/shims:"* ]]
  [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]
}

@test "agent env: removes single stale mise install dir without requiring duplicate" {
  export HOME="$BATS_TEST_TMPDIR/home"
  local installs="$HOME/.local/share/mise/installs"
  local stale_sessions="$installs/shiv-sessions/0.4.1/bin"

  export PATH="/mock/bin:$stale_sessions:/usr/bin:/bin"

  shimmer_prepare_agent_runtime_path

  [[ ":$PATH:" != *":$stale_sessions:"* ]]
  [[ ":$PATH:" == *":/mock/bin:"* ]]
  [[ ":$PATH:" == *":/usr/bin:"* ]]
  [[ ":$PATH:" == *":/bin:"* ]]
}

@test "agent env: preserves non-mise path order and does not duplicate stable entries" {
  export HOME="$BATS_TEST_TMPDIR/home"
  local data_dir="$HOME/.local/share/mise"
  local shims="$data_dir/shims"
  local local_bin="$HOME/.local/bin"

  export PATH="/mock/bin:$shims:/custom/bin:$local_bin:/tail/bin:/usr/bin:/bin"

  shimmer_prepare_agent_runtime_path

  [ "$PATH" = "/mock/bin:$shims:/custom/bin:$local_bin:/tail/bin:/usr/bin:/bin" ]
}
