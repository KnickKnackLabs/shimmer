#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  MOCK_DIR="$BATS_TEST_TMPDIR/mock-bin"
  BATS_LOG="$BATS_TEST_TMPDIR/bats.log"
  mkdir -p "$MOCK_DIR"
  export BATS_LOG

  cat > "$MOCK_DIR/bats" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'jobs=%s\n' "${BATS_NUMBER_OF_PARALLEL_JOBS:-}"
  printf 'runner=%s\n' "${BATS_PARALLEL_BINARY_NAME:-}"
  for arg in "$@"; do
    printf 'arg=%s\n' "$arg"
  done
} > "$BATS_LOG"
SH

  cat > "$MOCK_DIR/rush" <<'SH'
#!/usr/bin/env bash
exit 0
SH

  chmod +x "$MOCK_DIR/bats" "$MOCK_DIR/rush"

  export BATS_COMMAND="$MOCK_DIR/bats"
  export RUSH_COMMAND="$MOCK_DIR/rush"
  unset BATS_NUMBER_OF_PARALLEL_JOBS BATS_PARALLEL_BINARY_NAME
}

run_test_task() {
  (cd "$REPO_DIR" && mise run -q test "$@")
}

log_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$BATS_LOG"
}

arg_count() {
  local expected="$1"
  awk -F= -v expected="$expected" '$1 == "arg" && substr($0, 5) == expected { count++ } END { print count + 0 }' "$BATS_LOG"
}

logged_arguments() {
  sed -n 's/^arg=//p' "$BATS_LOG"
}

@test "test task defaults to four Rush jobs across files" {
  run run_test_task
  [ "$status" -eq 0 ]
  [[ "$output" == *"4 jobs across files"* ]]
  [ "$(log_value jobs)" = "4" ]
  [ "$(log_value runner)" = "$MOCK_DIR/rush" ]
  [ "$(arg_count --no-parallelize-within-files)" -eq 1 ]
  [ "$(arg_count --recursive)" -eq 1 ]
  [ "$(arg_count "$REPO_DIR/test/")" -eq 1 ]
}

@test "bare suite names resolve to suite directories" {
  run run_test_task gpg --filter strip_wrapping
  [ "$status" -eq 0 ]
  [ "$(arg_count "$REPO_DIR/test/gpg")" -eq 1 ]
  [ "$(arg_count --filter)" -eq 1 ]
  [ "$(arg_count strip_wrapping)" -eq 1 ]
  [ "$(arg_count --recursive)" -eq 0 ]
}

@test "explicit jobs override is forwarded once" {
  run run_test_task --jobs 3 gpg
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 jobs across files"* ]]
  [ "$(log_value jobs)" = "" ]
  [ "$(arg_count --jobs)" -eq 1 ]
  [ "$(arg_count 3)" -eq 1 ]
  [ "$(arg_count --no-parallelize-within-files)" -eq 1 ]
}

@test "environment jobs override the detected default" {
  export BATS_NUMBER_OF_PARALLEL_JOBS=2

  run run_test_task gpg
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 jobs across files"* ]]
  [ "$(log_value jobs)" = "2" ]
  [ "$(arg_count --jobs)" -eq 0 ]
}

@test "environment serial opt-out does not require Rush" {
  export BATS_NUMBER_OF_PARALLEL_JOBS=1
  export RUSH_COMMAND="$MOCK_DIR/missing-rush"

  run run_test_task gpg
  [ "$status" -eq 0 ]
  [[ "$output" == *"BATS parallelism: serial"* ]]
  [ "$(arg_count --no-parallelize-within-files)" -eq 0 ]
}

@test "CLI serial opt-out does not require Rush" {
  export RUSH_COMMAND="$MOCK_DIR/missing-rush"

  run run_test_task --jobs 1 gpg
  [ "$status" -eq 0 ]
  [[ "$output" == *"BATS parallelism: serial"* ]]
  [ "$(arg_count --no-parallelize-within-files)" -eq 0 ]
}

@test "parallel execution fails clearly when the selected runner is unavailable" {
  export RUSH_COMMAND="$MOCK_DIR/missing-rush"

  run -127 run_test_task gpg
  [ "$status" -eq 127 ]
  [[ "$output" == *"parallel runner '$MOCK_DIR/missing-rush' is unavailable for 4 jobs"* ]]
  [[ "$output" == *"run 'mise install' or use --jobs 1"* ]]
  [ ! -e "$BATS_LOG" ]
}

@test "environment runner override is preserved" {
  cp "$MOCK_DIR/rush" "$MOCK_DIR/alternate-runner"
  export BATS_PARALLEL_BINARY_NAME="$MOCK_DIR/alternate-runner"

  run run_test_task gpg
  [ "$status" -eq 0 ]
  [ "$(log_value runner)" = "$MOCK_DIR/alternate-runner" ]
}

@test "CLI runner override is preserved" {
  cp "$MOCK_DIR/rush" "$MOCK_DIR/alternate-runner"

  run run_test_task --parallel-binary-name "$MOCK_DIR/alternate-runner" gpg
  [ "$status" -eq 0 ]
  [ "$(arg_count --parallel-binary-name)" -eq 1 ]
  [ "$(arg_count "$MOCK_DIR/alternate-runner")" -eq 1 ]
}

@test "invalid job override fails before BATS" {
  export BATS_NUMBER_OF_PARALLEL_JOBS=lots

  run run_test_task gpg
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be a positive integer"* ]]
  [ ! -e "$BATS_LOG" ]
}

@test "missing job override fails before BATS" {
  run run_test_task --jobs
  [ "$status" -eq 2 ]
  [[ "$output" == *"--jobs requires a positive integer"* ]]
  [ ! -e "$BATS_LOG" ]
}

@test "filter values that resemble parallel flags remain filter values" {
  run run_test_task --filter --jobs gpg
  [ "$status" -eq 0 ]
  [ "$(logged_arguments)" = "$(printf '%s\n' \
    --print-output-on-failure \
    --no-parallelize-within-files \
    --filter \
    --jobs \
    "$REPO_DIR/test/gpg")" ]
}

@test "filter values matching suite names are not resolved as targets" {
  run run_test_task --filter gpg agent
  [ "$status" -eq 0 ]
  [ "$(logged_arguments)" = "$(printf '%s\n' \
    --print-output-on-failure \
    --no-parallelize-within-files \
    --filter \
    gpg \
    "$REPO_DIR/test/agent")" ]
}

@test "canonical task runs separate BATS files concurrently" {
  probe_dir="$BATS_TEST_TMPDIR/parallel-probe"
  barrier_dir="$BATS_TEST_TMPDIR/barrier"
  mkdir -p "$probe_dir" "$barrier_dir"

  test_keyword='@test'
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"first worker observes second worker\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/one"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/two" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/one.bats"

  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"second worker observes first worker\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/two"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/one" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/two.bats"

  run env -i \
    HOME="$HOME" \
    PATH="$PATH" \
    TMPDIR="${TMPDIR:-/tmp}" \
    MISE_TRUSTED_CONFIG_PATHS="$REPO_DIR" \
    PROBE_DIR="$barrier_dir" \
    bash -c 'cd "$1" && mise run -q test "$2"' _ "$REPO_DIR" "$probe_dir"

  [ "$status" -eq 0 ]
  [[ "$output" == *"jobs across files"* ]]
}
