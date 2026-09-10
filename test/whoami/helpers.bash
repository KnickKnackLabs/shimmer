# Helpers for shimmer `whoami` BATS tests
#
# Suite-specific: a mock `gh` on PATH so the identity lookups make no network
# calls. Shared helpers (mock_shimmer, shimmer wrapper) come from
# test/helpers.bash.

# shellcheck source=test/helpers.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helpers.bash"

# Create a mock `gh` binary on PATH.
# The `auth status` line matches gh 2.100.0, which prints "account <user>" and
# no " as " separator. Do not swap in the older " as " wording: the fallback
# assertion would then pass on output real gh no longer produces.
# Usage: mock_gh_binary [login]
mock_gh_binary() {
  local login="${1:-mock-user}"
  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin-$$"
  mkdir -p "$MOCK_BIN"

  cat > "$MOCK_BIN/gh" <<MOCK
#!/usr/bin/env bash
case "\$1 \$2" in
  "api user") echo "$login" ;;
  "auth status") echo "  ✓ Logged in to github.com account $login (keyring)" ;;
  *) echo "mock gh: unknown command \$*" >&2; exit 1 ;;
esac
MOCK
  chmod +x "$MOCK_BIN/gh"

  export PATH="$MOCK_BIN:$PATH"
}
