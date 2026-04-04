# Helpers for shimmer telemetry BATS tests

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.bash"

setup() {
  export TELEMETRY_FILE="$BATS_TEST_TMPDIR/telemetry-$$.jsonl"
  unset TELEMETRY_HOOK
  mock_shimmer
}
