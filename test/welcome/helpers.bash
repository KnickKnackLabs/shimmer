# Helpers for shimmer welcome BATS tests
#
# Tests check functions directly by sourcing lib/checks.sh —
# no need to run the full welcome task through an overlay.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.bash"
source "$SHIMMER_DIR/lib/checks.sh"

# Set up a minimal environment for check_email.
# Creates a himalaya config so the check proceeds past "not configured".
# Usage: setup_email [agent_name]
setup_email() {
  local agent="${1:-test-agent}"
  export AGENT="$agent"

  HIMALAYA_CONFIG="$BATS_TEST_TMPDIR/himalaya-$$.toml"
  cat > "$HIMALAYA_CONFIG" <<EOF
[accounts.${agent}]
email = "${agent}@ricon.family"
EOF
  export HIMALAYA_CONFIG
}
