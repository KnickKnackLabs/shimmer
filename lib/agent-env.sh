#!/usr/bin/env bash
# Environment preparation for long-lived agent child processes.
#
# `shimmer agent` is itself a mise task, but the pi/sessions process it launches
# is a user-facing agent runtime. Task-scoped mise state should not leak into
# that runtime, while identity-bearing environment must remain intact.

shimmer_mise_data_dir() {
  if [ -n "${MISE_DATA_DIR:-}" ]; then
    printf '%s\n' "$MISE_DATA_DIR"
  elif [ -n "${XDG_DATA_HOME:-}" ]; then
    printf '%s\n' "$XDG_DATA_HOME/mise"
  elif [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME/.local/share/mise"
  fi
}

shimmer_scrub_caller_pwd_env() {
  local name
  while IFS= read -r name; do
    case "$name" in
      CALLER_PWD|*_CALLER_PWD) unset "$name" ;;
    esac
  done < <(compgen -e)
}

shimmer_scrub_mise_task_env() {
  local name
  while IFS= read -r name; do
    case "$name" in
      # These describe the mise task currently launching the agent. Leaving them
      # set makes later direct tool/test invocations believe they still run from
      # shimmer's task root.
      MISE_CONFIG_ROOT|MISE_ORIGINAL_CWD|MISE_PROJECT_ROOT|MISE_TASK_*|usage_*) unset "$name" ;;
    esac
  done < <(compgen -e)
}

shimmer_scrub_legacy_prompt_env() {
  # Shimmer no longer transports prompt text through ambient environment.
  # Clear stale values left by older `shimmer as` sessions before launching
  # pi/sessions so prompt-neutral callers stay prompt-neutral after upgrades.
  unset AGENT_IDENTITY
}

shimmer_path_contains() {
  local needle="$1"
  local path_rest entry
  path_rest="${PATH:-}:"

  while [ -n "$path_rest" ]; do
    entry="${path_rest%%:*}"
    path_rest="${path_rest#*:}"
    [ "$entry" = "$needle" ] && return 0
  done

  return 1
}

shimmer_append_path_if_missing() {
  local entry="$1"
  [ -n "$entry" ] || return 0
  shimmer_path_contains "$entry" && return 0

  if [ -n "${PATH:-}" ]; then
    export PATH="$PATH:$entry"
  else
    export PATH="$entry"
  fi
}

# Cross the boundary from shimmer's mise task into a long-lived agent runtime.
#
# The launcher task may have direct mise install directories on PATH, such as
# ~/.local/share/mise/installs/shiv-sessions/0.4.1/bin. Those directories are
# activation artifacts for the launcher repo, not part of the agent runtime
# contract. If they survive, they can shadow later repo-specific `mise exec`
# tool selections for the entire interactive session.
#
# Do not reset wholesale to __MISE_ORIG_PATH here: callers/tests may have
# intentionally prepended non-mise directories for harnesses, wrappers, or
# mocks. Preserve ordinary PATH entries, remove direct mise install entries,
# and make the stable command surfaces available through mise shims and
# ~/.local/bin.
shimmer_prepare_agent_runtime_path() {
  local data_dir installs path_rest entry new_path
  if ! data_dir="$(shimmer_mise_data_dir)"; then
    data_dir=""
  fi
  [ -n "$data_dir" ] || return 0

  installs="$data_dir/installs"
  path_rest="${PATH:-}:"
  new_path=""

  while [ -n "$path_rest" ]; do
    entry="${path_rest%%:*}"
    path_rest="${path_rest#*:}"

    case "$entry" in
      "$installs"/*) continue ;;
    esac

    if [ -z "$new_path" ]; then
      new_path="$entry"
    else
      new_path="$new_path:$entry"
    fi
  done

  export PATH="$new_path"
  shimmer_append_path_if_missing "$data_dir/shims"
  [ -n "${HOME:-}" ] && shimmer_append_path_if_missing "$HOME/.local/bin"
}

shimmer_prepare_agent_child_env() {
  shimmer_scrub_caller_pwd_env
  shimmer_scrub_mise_task_env
  shimmer_scrub_legacy_prompt_env
  shimmer_prepare_agent_runtime_path
}
