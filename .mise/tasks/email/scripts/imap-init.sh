# Sourceable helper for email tasks that need direct IMAP access.
# Sets: AGENT, CONFIG_FILE, PASS
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/scripts/imap-init.sh"

export RUST_LOG=error

# Determine current agent from environment or git config
if [ -n "$GIT_AUTHOR_EMAIL" ]; then
  AGENT=$(echo "$GIT_AUTHOR_EMAIL" | sed 's/@ricon\.family$//')
elif git config user.email 2>/dev/null | grep -q '@ricon.family'; then
  AGENT=$(git config user.email | sed 's/@ricon\.family$//')
else
  echo "No agent identity detected. Run: eval \$(shimmer as <agent>)"
  return 1 2>/dev/null || exit 1
fi

CONFIG_FILE="${HOME}/.config/himalaya/config.toml"
if [ ! -f "$CONFIG_FILE" ] || ! grep -q "accounts.$AGENT" "$CONFIG_FILE" 2>/dev/null; then
  echo "Email not configured for $AGENT. Run: shimmer email:setup $AGENT"
  return 1 2>/dev/null || exit 1
fi

# Get password from himalaya config
PASS=$(grep -A30 "accounts.$AGENT" "$CONFIG_FILE" | grep 'auth.raw' | head -1 | sed 's/.*= *"//' | sed 's/"$//')

if [ -z "$PASS" ]; then
  echo "Could not read email password from config"
  return 1 2>/dev/null || exit 1
fi
