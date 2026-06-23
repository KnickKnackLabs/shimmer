#!/usr/bin/env bash
# Shared fixtures for top-level shimmer smoke tests.

# Run a repo task through mise so tests exercise the real task path.
shimmer_task() {
  cd "$REPO_DIR" && SHIMMER_CALLER_PWD="${SHIMMER_CALLER_PWD:-$REPO_DIR}" mise run -q "$@"
}
export -f shimmer_task
