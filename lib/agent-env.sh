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

shimmer_canonical_directory() {
  local path="$1"
  local label="$2"

  if [ -z "$path" ]; then
    echo "Error: $label is empty" >&2
    return 1
  fi
  if [ ! -d "$path" ]; then
    echo "Error: $label is not a directory: $path" >&2
    return 1
  fi

  (cd "$path" && pwd -P)
}

# Resolve AGENT_HOME as the selected identity's repository root, then require
# another path to identify that same physical directory. Callers use this
# before approving project-scoped executable resources for an agent runtime.
shimmer_require_agent_home_path() {
  local path="$1"
  local label="$2"
  local agent_home candidate repo_root

  if [ -z "${AGENT_HOME:-}" ]; then
    echo "Error: AGENT_HOME is not set. Run: eval \$(shimmer as <agent>)" >&2
    return 1
  fi

  agent_home=$(shimmer_canonical_directory "$AGENT_HOME" "AGENT_HOME") || return 1
  candidate=$(shimmer_canonical_directory "$path" "$label") || return 1

  if ! repo_root=$(git -C "$agent_home" rev-parse --show-toplevel 2>/dev/null); then
    echo "Error: AGENT_HOME is not a Git worktree: $agent_home" >&2
    return 1
  fi
  repo_root=$(shimmer_canonical_directory "$repo_root" "AGENT_HOME Git root") || return 1

  if [ "$repo_root" != "$agent_home" ]; then
    echo "Error: AGENT_HOME must identify the agent home repository root" >&2
    echo "  AGENT_HOME: $agent_home" >&2
    echo "  Git root:   $repo_root" >&2
    return 1
  fi

  if [ "$candidate" != "$agent_home" ]; then
    echo "Error: $label does not match the authenticated agent home" >&2
    echo "  $label: $candidate" >&2
    echo "  agent home: $agent_home" >&2
    return 1
  fi

  printf '%s\n' "$agent_home"
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
  shimmer_prepare_agent_runtime_path
}
